# Zero-Jump Form Binding & IME Integrity Invariants Specification
## (Zero-Jump Form Binding & IME Integrity Invariants: WhatTextEditingController)

> **"When users type Korean or Japanese, cursor jumping or syllable fragmentation reveals synchronization defects between unidirectional reactive state and platform input methods. What guarantees total IME integrity through mutually exclusive ping-pong shields."**  
> — *What Framework Core Systems Group*

---

## 1. Overview and Background: The Collision Between Unidirectional State and Bidirectional Text Controllers

Synchronizing Flutter's standard `TextEditingController` with a unidirectional reactive handle (`WhatController<String>`) induces three systemic defects:

1. **Cursor Jumping**:
   - When users edit text in the middle of a string, `controller.addListener` updates reactive state.
   - Pushing the state back via `controller.text = newValue` triggers Flutter's default selection reset, snapping the cursor to the end of the input field.
2. **CJK IME Buffer Corruption**:
   - For composition-based scripts (Korean Hangul syllables, Japanese Kanji conversions, Chinese Pinyin), assigning text mid-composition destroys the OS composing buffer, fragmenting syllables (e.g., `'가'` -> `'ㄱㅏ'`).
3. **Re-entrant Ping-Pong Loops**:
   - Keyboard Input -> State Update -> Controller Notification -> Widget Rebuild creates infinite re-entrant loops that saturate CPU cycles.

`package:what_flutter`'s `WhatTextEditingController` resolves this through **Mutual Exclusion Mutexes** and **Smart Selection Clamping**.

---

## 2. Bidirectional Form Pipeline Architecture

```text
┌────────────────────────────────────────────────────────────────────────┐
│               WhatTextEditingController Flow                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Keyboard Typing (UI) ]              [ External State Change ]      │
│              │                                      │                  │
│              ▼                                      ▼                  │
│      TextEditingValue                     WhatController<String>       │
│              │                                      │                  │
│              ▼ [_isUpdatingFromUI = true]           ▼                  │
│       target.set(text)                     RawWhatTerminal             │
│              │                                      │                  │
│              ▼                                      ▼                  │
│    _onWhatChanged ignores!                _isUpdatingFromWhat = true   │
│    (0-jump, IME intact)                   Smart Selection Clamping     │
│                                                     │                  │
│                                                     ▼                  │
│                                            TextEditingValue (safe!)    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. The 5 Form Integrity Protection Mechanisms

### 1) Cursor Jumping Immunity
While the user types, `_isUpdatingFromUI` activates. Incoming state notifications during active typing never overwrite the controller's `value`, keeping the caret position intact.

### 2) CJK IME Composition Buffer Protection
During active composition, `TextEditingValue.isComposingRangeValid` evaluates to `true`. What defers external state pushes until the syllable completes, preventing character fragmentation.

### 3) Ping-Pong Re-entrancy Shield
UI mutation flags (`_isUpdatingFromUI`) and state mutation flags (`_isUpdatingFromWhat`) operate as mutually exclusive mutexes, collapsing bidirectional cycles into a single pass.

### 4) Smart Selection Clamping
When external business logic formats or resets text:
```dart
// packages/what_flutter/lib/src/widgets/editable_text.dart
final newSelection = TextSelection(
  baseOffset: currentSelection.baseOffset.clamp(0, newText.length),
  extentOffset: currentSelection.extentOffset.clamp(0, newText.length),
);
```
The caret position clamps within `[0, newText.length]`, preventing `IndexOutOfRangeException` crashes.

### 5) Declarative Form Resets via `clearOnEmpty`
When `target.empty()` is called:
```dart
// packages/what_flutter/lib/src/widgets/editable_text.dart
void _onWhatChanged() {
  if (!_target.hasData) {
    if (clearOnEmpty && text.isNotEmpty) {
      _isUpdatingFromWhat = true;
      try {
        value = TextEditingValue.empty;
      } finally {
        _isUpdatingFromWhat = false;
      }
    }
    return;
  }
  ...
}
```
With `clearOnEmpty: true` (default), calling `queryController.empty()` in domain logic clears the UI field instantly without visual jank.

---

## 4. Production Code Patterns

### 1. Reactive Search Input with Declarative Reset
```dart
class SearchBarWidget extends StatelessWidget {
  SearchBarWidget({super.key});

  final queryController = WhatController('');
  late final textController = WhatTextEditingController(
    queryController,
    clearOnEmpty: true,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: textController,
            decoration: const InputDecoration(hintText: 'Enter search query...'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => queryController.empty(), // Clears UI text automatically
        ),
      ],
    );
  }
}
```

### 2. Multi-Field Form Validation with GlobalKey<FormState>
```dart
base class LoginForm extends WhatWidget {
  LoginForm({super.key});

  final formKey = GlobalKey<FormState>();
  final emailController = WhatController('');
  final passwordController = WhatController('');

  late final emailTextCtrl = WhatTextEditingController(emailController);
  late final passwordTextCtrl = WhatTextEditingController(passwordController);

  @override
  Widget build(BuildContext context, WhatVia via) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: emailTextCtrl,
            validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
          ),
          TextFormField(
            controller: passwordTextCtrl,
            obscureText: true,
            validator: (v) => v!.length >= 8 ? null : 'Minimum 8 characters required',
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                // Submit credentials
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. Foundational Engineering Invariants

1. **Re-entrant Mutex Invariant**:
   UI updates and state pushes execute under mutual exclusion, emitting at most one LPDAG Push-Dirty pulse per frame.
2. **Composition Preservation Invariant**:
   While `isComposingRangeValid == true`, external mutations never overwrite active composition buffers.
3. **Selection Invariant**:
   Text selections clamp monotonically within `[0, text.length]`, preventing out-of-bounds selection errors under all conditions.
