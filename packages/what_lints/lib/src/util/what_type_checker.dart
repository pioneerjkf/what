// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../what_lints.dart';

/// Centralized type-checking and AST analysis utility for the What framework ecosystem.
abstract final class WhatTypeChecker {
  // ===========================================================================
  // Package URI Prefixes
  // ===========================================================================

  /// Package URI prefixes belonging to the What ecosystem.
  static const _whatPackagePrefixes = {
    'package:what/',
    'package:what_flutter/',
    'package:what_extensions/',
    'package:what_lints/',
  };

  /// Returns `true` if the given URI belongs to a What package.
  static bool isWhatPackageUri(String? uri) {
    if (uri == null) return false;
    for (final prefix in _whatPackagePrefixes) {
      if (uri.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Returns `true` if the [element] is declared inside a What package.
  static bool isFromWhatPackage(Element? element) {
    if (element == null) return false;
    return isWhatPackageUri(element.library?.identifier);
  }

  /// Returns `true` if the [type] represents the given [className] from a What package.
  static bool _isWhatClass(DartType? type, String className) {
    if (type == null) return false;
    final element = type.element;
    if (element == null) return false;
    if (element.name == className && isFromWhatPackage(element)) return true;
    if (type is InterfaceType) {
      for (final superType in type.allSupertypes) {
        if (superType.element.name == className &&
            isFromWhatPackage(superType.element)) {
          return true;
        }
      }
    }
    return false;
  }

  // ===========================================================================
  // ===========================================================================
  // Core Type Name Sets (100% Verified Active Codebase AST Symbols)
  // ===========================================================================

  /// Core What reactive DAG, state, controller, terminal, and UI types.
  static const _whatTypes = {
    // 1. Core State Nodes & Protocol
    'What',
    'WhatState',
    'WhatSnapshot',
    'WhatStatus',
    'RefreshableWhat',

    // 2. Producers & Controllers
    'WhatController',
    'RawWhatController',
    'WhatListController',
    'WhatSetController',
    'WhatMapController',
    'WhatCoupler',
    'WhatSignalController',

    // 3. Dependency Manifest & Signals
    'WhatVia',
    'WhatUntracked',
    'WhatSignal',

    // 4. Terminals & Boundary Sinks
    'RawTerminal',
    'RawWhatTerminal',
    'RawViaTerminal',
    'RawComputedTerminal',

    // 5. Effect Domain
    'Effect',
    'EffectHandle',
    'EffectGroup',
    'EffectRunner',
    'ThrottleEffect',
    'DebounceEffect',

    // 6. Flutter UI & Widgets
    'WhatWidget',
    'WhatVsyncWidget',
    'WhatListener',
    'UnaryWhatListener',

    // 7. Durable Animation Controllers
    'FrozenAnimationController',
    'CatchUpAnimationController',
    'DurableAnimationController',
    'ScopedAnimationController',
  };

  /// Core animation types declared in what_flutter.
  static const _coreAnimationTypes = {
    'FrozenAnimationController',
    'CatchUpAnimationController',
    'DurableAnimationController',
    'ScopedAnimationController',
  };

  // ===========================================================================
  // What Type & Target Checks
  // ===========================================================================

  /// Returns `true` if the [type] is a What ecosystem type.
  static bool isWhatType(DartType? type) {
    if (type == null) return false;
    if (type is DynamicType || type is InvalidType) return false;

    // Check RecordType fields recursively
    if (type is RecordType) {
      return type.positionalFields.any((f) => isWhatType(f.type)) ||
          type.namedFields.any((f) => isWhatType(f.type));
    }

    final element = type.element;
    if (element == null) return false;

    final typeName = element.name ?? '';
    if (_whatTypes.contains(typeName)) {
      return true;
    }

    // Check supertypes/interfaces (e.g. custom classes implementing What / WhatState)
    if (type is InterfaceType) {
      for (final superType in type.allSupertypes) {
        final superName = superType.element.name;
        if (_whatTypes.contains(superName)) {
          return true;
        }
      }
    }

    if (isFromWhatPackage(element)) {
      return typeName.contains('Entry') || typeName.contains('Functor');
    }

    return false;
  }

  /// Returns `true` if the [expr] represents a verified What target node
  /// based on Analyzer static type analysis, with syntax fallback for unresolved ASTs.
  static bool isWhatTarget(Expression? expr) {
    if (expr == null) return false;
    final staticType = expr.staticType;
    if (staticType != null &&
        staticType is! DynamicType &&
        staticType is! InvalidType) {
      return isWhatType(staticType);
    }
    // Strict identifier naming fallback for unresolved ASTs in standalone unit tests
    if (expr is SimpleIdentifier) {
      final name = expr.name;
      return name == 'what' || name.endsWith('What');
    }
    return false;
  }

  /// Returns `true` if the [type] is or implements `What`.
  static bool isWhatClass(DartType? type) => _isWhatClass(type, 'What');

  /// Returns `true` if the [type] is or implements `WhatState`.
  static bool isWhatStateClass(DartType? type) =>
      _isWhatClass(type, 'WhatState');

  /// Returns `true` if the [expr] represents a verified trackable source for `via`
  /// (e.g. `What`, `WhatState`, `WhatController`, `RawWhatTerminal`, `WhatCoupler`).
  static bool isTrackableWhatTarget(Expression? expr) {
    if (expr == null) return false;
    final unwrapped = expr.unParenthesized;
    final staticType = unwrapped.staticType;
    if (staticType != null &&
        staticType is! DynamicType &&
        staticType is! InvalidType) {
      return _isWhatClass(staticType, 'What') ||
          _isWhatClass(staticType, 'WhatState') ||
          _isWhatClass(staticType, 'WhatController') ||
          _isWhatClass(staticType, 'RawWhatController') ||
          _isWhatClass(staticType, 'RawWhatTerminal') ||
          _isWhatClass(staticType, 'RawTerminal') ||
          _isWhatClass(staticType, 'WhatCoupler');
    }
    // Strict identifier naming fallback for unresolved ASTs
    if (unwrapped is SimpleIdentifier) {
      final name = unwrapped.name;
      return name == 'what' || name.endsWith('What');
    }
    if (unwrapped is PropertyAccess) {
      final name = unwrapped.propertyName.name;
      return name == 'what' || name.endsWith('What');
    }
    if (unwrapped is PrefixedIdentifier) {
      final name = unwrapped.identifier.name;
      return name == 'what' || name.endsWith('What');
    }
    if (unwrapped is MethodInvocation) {
      final name = unwrapped.methodName.name;
      return name == 'whatOf' ||
          name == 'maybeWhatOf' ||
          name == 'what' ||
          name.endsWith('What');
    }
    return false;
  }

  /// Stateful What producer controller and coupler types.
  static const _coreControllerTypes = {
    'WhatController',
    'RawWhatController',
    'WhatListController',
    'WhatSetController',
    'WhatMapController',
    'WhatCoupler',
    'WhatSignalController',
  };

  /// Returns `true` if the [typeName] is a stateful controller or coupler type.
  static bool isControllerOrCouplerType(String? typeName) {
    if (typeName == null) return false;
    return _coreControllerTypes.contains(typeName);
  }

  /// Returns `true` if the [type] is a What animation controller type.
  static bool isWhatAnimationController(DartType? type) {
    if (type == null) return false;
    final element = type.element;
    if (element == null) return false;

    final typeName = element.name ?? '';
    return _coreAnimationTypes.contains(typeName);
  }

  /// Returns `true` if the [type] represents `ScopedAnimationController`.
  static bool isScopedAnimationController(DartType? type) {
    if (type == null) return false;
    return _isWhatClass(type, 'ScopedAnimationController');
  }

  // ===========================================================================
  // Reactive Bridging & Adapter Members
  // ===========================================================================

  /// Verified factory & extension methods that create reactive bridges
  /// (e.g. `stream.toWhat()`, `listenable.toWhatBy(...)`, `what.toListenable()`).
  static const _reactiveBridgingMethods = {
    'toWhat',
    'toWhatBy',
    'toListenable',
  };

  /// Verified adapter getters (empty in modern What: all bridges are explicit methods).
  static const Set<String> _reactiveBridgingProperties = {};

  /// Returns `true` if the given method [name] represents a reactive bridging factory method.
  static bool isReactiveBridgingMethod(String? name) {
    if (name == null) return false;
    return _reactiveBridgingMethods.contains(name);
  }

  /// Returns `true` if the given property [name] represents a reactive adapter getter.
  static bool isReactiveBridgingProperty(String? name) {
    if (name == null) return false;
    return _reactiveBridgingProperties.contains(name);
  }

  // ===========================================================================
  // 1. Pipeline Read (Payload Extraction) Members
  // ===========================================================================

  /// Verified member properties that read reactive node payload on `WhatState`.
  static const _pipelineReadProperties = {
    'data',
    'dataOrNull',
    'snapshot',
    'hasData',
    'isEmpty',
    'emptyReason',
    'hasError',
    'error',
    'stackTrace',
  };

  /// Verified member methods that evaluate and read reactive node payload on `WhatState`.
  static const _pipelineReadMethods = {
    'dataOrElse',
    'match',
    'matchOrElse',
    'matchOrNull',
    'when',
    'whenOrElse',
    'whenOrNull',
  };

  /// Returns `true` if the given property [name] represents a reactive payload extraction getter.
  static bool isPipelineReadProperty(String? name) {
    if (name == null) return false;
    return _pipelineReadProperties.contains(name);
  }

  /// Returns `true` if the given method [name] represents a reactive payload extraction method.
  static bool isPipelineReadMethod(String? name) {
    if (name == null) return false;
    return _pipelineReadMethods.contains(name);
  }

  // ===========================================================================
  // 2. Pipeline Write (State & Topology Mutation) Members
  // ===========================================================================

  /// Verified member methods that write state or modify reactive graph topology.
  static const _pipelineWriteMethods = {
    // 1. Controller state writes
    'set',
    'setGuarded',
    'setError',
    'empty',
    'markDirty',

    // 2. Collection controller transactional draft edits
    'edit',
    'editGuarded',

    // 3. Coupler dynamic socket coupling
    'couple',
    'coupleGuarded',
    'decouple',
    'tryDecoupling',

    // 4. Terminal dynamic source swaps
    'swapSource',
  };

  /// Verified member properties whose setters write state or modify topology.
  static const _pipelineWriteProperties = {
    'data',
  };

  /// Returns `true` if the given method [name] represents a state-writing or topology-modifying method.
  static bool isPipelineWriteMethod(String? name) {
    if (name == null) return false;
    return _pipelineWriteMethods.contains(name);
  }

  /// Returns `true` if the given property [name] represents a state-writing or topology-modifying setter.
  static bool isPipelineWriteProperty(String? name) {
    if (name == null) return false;
    return _pipelineWriteProperties.contains(name);
  }

  // ===========================================================================
  // 3. Pipeline Evaluation (Transformation & UI) Members
  // ===========================================================================

  /// Verified pipeline evaluation methods where synchronous writes cause reentrancy errors.
  static const _pipelineEvaluationMethods = {
    // 1. Core What transformation & derivation functors
    'computed',
    'switched',
    'managed',
    'distinct',
    'effect',

    // 2. What Flutter UI render & listener functors
    'build',
    'drive',
    'animate',
    'match',
    'when',
    'listen',
  };

  /// Returns `true` if the given method [name] represents a pipeline evaluation or transform method.
  static bool isPipelineEvaluationMethod(String? name) {
    if (name == null) return false;
    return _pipelineEvaluationMethods.contains(name);
  }

  /// Returns `true` if the [node] represents an active What pipeline evaluation invocation
  /// (e.g. `computed(...)`, `composed(...)`, `switched(...)`, `managed(...)`, `what.build(...)`).
  ///
  /// **Core Safety Philosophy:**
  /// Executing state writes (`controller.set()`, `controller.data = ...`) synchronously inside
  /// any What pipeline invocation triggers a reentrancy error or infinite loop.
  static bool isWhatPipelineInvocation(AstNode node) {
    if (node is FunctionExpressionInvocation) {
      final function = node.function;
      final funcName =
          function is SimpleIdentifier ? function.name : function.toSource();
      if (funcName == 'composed' ||
          funcName == 'computed' ||
          funcName == 'switched' ||
          funcName == 'managed' ||
          funcName == 'effect') {
        final element = function is SimpleIdentifier ? function.element : null;
        if (element == null) return true;
        return isFromWhatPackage(element);
      }
      return false;
    }

    if (node is! MethodInvocation) return false;

    final name = node.methodName.name;

    // 1. Top-level functors: composed(), computed(), switched(), managed(), effect()
    if ((name == 'composed' ||
            name == 'computed' ||
            name == 'switched' ||
            name == 'managed' ||
            name == 'effect') &&
        node.target == null) {
      final element = node.methodName.element;
      if (element == null) return true;
      return isFromWhatPackage(element);
    }

    // 2. What pipeline transformation and UI render methods
    if (_pipelineEvaluationMethods.contains(name)) {
      final target = node.realTarget;
      if (target == null) return true;

      final targetType = target.staticType;
      if (targetType == null) return false;

      // 2.1. Record tuple functor: (whatA, whatB).build(...)
      if (targetType is RecordType) return true;

      // 2.2. What reactive state node methods: what.build(...), what.match(...)
      if (isWhatType(targetType)) return true;

      // 2.3. What Animation Controller functors: controller.animate(...)
      if (isWhatAnimationController(targetType)) return true;
    }

    return false;
  }

  /// Resolves the functor name for the given invocation callee expression.
  static String? resolveFunctorName(InvocationExpression node) {
    Expression callee;
    String sourceStr;

    if (node is MethodInvocation) {
      callee = node.methodName;
      sourceStr = node.target != null
          ? '${node.target!.toSource()}.${node.methodName.name}'
          : node.methodName.name;
    } else if (node is FunctionExpressionInvocation) {
      callee = node.function;
      sourceStr = callee.toSource();
    } else {
      return null;
    }

    final type = callee.staticType;
    if (type is InterfaceType) {
      final name = type.element.name;
      if (name != null &&
          name.endsWith('Functor') &&
          isFromWhatPackage(type.element)) {
        return name;
      }
    }

    if (node is MethodInvocation && node.target != null) {
      final targetType = node.target!.staticType;
      if (targetType is InterfaceType) {
        final name = targetType.element.name;
        if (name != null &&
            name.endsWith('Functor') &&
            isFromWhatPackage(targetType.element)) {
          if (name == 'ComputedFunctor' && node.methodName.name == 'future')
            return 'ComputedFutureFunctor';
          if (name == 'ComputedFunctor' && node.methodName.name == 'stream')
            return 'ComputedStreamFunctor';
          if (name.startsWith('Composed') && node.methodName.name == 'child')
            return 'ComposedChildFunctor';
          if (name.startsWith('Composed') && node.methodName.name == 'children')
            return 'ComposedChildrenFunctor';
          if (name == 'ComposedFunctor' && node.methodName.name == 'context')
            return 'ComposedContextFunctor';
          if (name == 'ComposedFunctor' && node.methodName.name == 'vsync')
            return 'ComposedVsyncFunctor';
          if (name == 'ComposedFunctor' && node.methodName.name == 'drive')
            return 'ComposedDriveFunctor';
          if (name == 'ComposedFunctor' && node.methodName.name == 'animate')
            return 'ComposedAnimateFunctor';
          return name;
        }
      }
    }

    // Unresolved fallback
    if (sourceStr == 'computed') return 'ComputedFunctor';
    if (sourceStr == 'computed.future' || sourceStr == 'computed.async')
      return 'ComputedFutureFunctor';
    if (sourceStr == 'computed.stream') return 'ComputedStreamFunctor';
    if (sourceStr == 'switched') return 'SwitchedFunctor';
    if (sourceStr == 'managed' || sourceStr == 'What.managed')
      return 'ManagedFunctor';
    if (sourceStr == 'composed') return 'ComposedFunctor';
    if (sourceStr.startsWith('composed.') && sourceStr.endsWith('.child'))
      return 'ComposedChildFunctor';
    if (sourceStr.startsWith('composed.') && sourceStr.endsWith('.children'))
      return 'ComposedChildrenFunctor';
    if (sourceStr == 'composed.context') return 'ComposedContextFunctor';
    if (sourceStr == 'composed.vsync') return 'ComposedVsyncFunctor';
    if (sourceStr == 'composed.drive') return 'ComposedDriveFunctor';
    if (sourceStr == 'composed.animate') return 'ComposedAnimateFunctor';
    if (sourceStr == 'composed.child') return 'ComposedChildFunctor';
    if (sourceStr == 'composed.children') return 'ComposedChildrenFunctor';
    return null;
  }

  // ===========================================================================
  // 4. WhatVia AST Manifest Helpers
  // ===========================================================================

  /// Returns `true` if the parameter represents a `WhatVia` dependency manifest handle.
  static bool isWhatViaParameter(FormalParameter param) {
    final element = param.declaredFragment?.element;
    if (element != null) {
      final type = element.type;
      if (type is! DynamicType && type is! InvalidType) {
        return _isWhatClass(type, 'WhatVia');
      }
    }

    final name = param.name?.lexeme;
    if (name == 'via') return true;

    if (param is SimpleFormalParameter) {
      final typeStr = param.type?.toSource();
      if (typeStr == 'WhatVia' || typeStr == 'WhatVia?') return true;
    }
    return false;
  }

  /// Returns `true` if the invocation represents a call to `via(what)`, `via.state(what)`, `via.tether(effect)`, or `via.of(context)` / `via.maybeOf(context)`.
  static bool isWhatViaInvocation(AstNode? node) {
    if (node == null) return false;

    // 1. Check for `via.of(...)`, `via.maybeOf(...)`, `via.state(...)`, `via.tether(...)`
    if (node is MethodInvocation) {
      final methodName = node.methodName.name;
      if (methodName == 'of' ||
          methodName == 'maybeOf' ||
          methodName == 'state' ||
          methodName == 'tether') {
        final target = node.target;
        if (target != null) {
          final targetType = target.staticType;
          if (targetType != null &&
              targetType is! DynamicType &&
              targetType is! InvalidType) {
            if (_isWhatClass(targetType, 'WhatVia')) {
              return true;
            }
          }
          if (target is SimpleIdentifier && target.name == 'via') {
            return true;
          }
        }
      }
    }

    Expression? function;
    if (node is MethodInvocation) {
      function = node.methodName;
    } else if (node is FunctionExpressionInvocation) {
      function = node.function;
    }

    if (function != null) {
      final staticType = function.staticType;
      if (staticType != null &&
          staticType is! DynamicType &&
          staticType is! InvalidType) {
        return _isWhatClass(staticType, 'WhatVia');
      }
    }

    if (node is MethodInvocation) {
      return node.methodName.name == 'via' && node.target == null;
    }
    if (node is FunctionExpressionInvocation) {
      final func = node.function;
      if (func is SimpleIdentifier && func.name == 'via') {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` if the invocation represents a call to `untracked(what)` or `untracked.state(what)`.
  static bool isWhatUntrackedInvocation(AstNode? node) {
    if (node == null) return false;

    // 1. Check for `untracked.state(...)`
    if (node is MethodInvocation) {
      final methodName = node.methodName.name;
      if (methodName == 'state') {
        final target = node.target;
        if (target != null) {
          final targetType = target.staticType;
          if (targetType != null &&
              targetType is! DynamicType &&
              targetType is! InvalidType) {
            if (_isWhatClass(targetType, 'WhatUntracked')) {
              return true;
            }
          }
          if (target is SimpleIdentifier && target.name == 'untracked') {
            return true;
          }
        }
      }
    }

    // 2. Check for `untracked(...)`
    Expression? function;
    if (node is MethodInvocation) {
      function = node.methodName;
    } else if (node is FunctionExpressionInvocation) {
      function = node.function;
    }

    if (function != null) {
      final staticType = function.staticType;
      if (staticType != null &&
          staticType is! DynamicType &&
          staticType is! InvalidType) {
        if (_isWhatClass(staticType, 'WhatUntracked')) {
          return true;
        }
      }
    }

    if (node is MethodInvocation) {
      return node.methodName.name == 'untracked' && node.target == null;
    }
    if (node is FunctionExpressionInvocation) {
      final func = node.function;
      if (func is SimpleIdentifier && func.name == 'untracked') {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` if the [expr] represents a `WhatVia` target expression.
  static bool isWhatViaTarget(Expression? expr) {
    if (expr == null) return false;
    final unwrapped = expr.unParenthesized;
    final staticType = unwrapped.staticType;
    if (staticType != null &&
        staticType is! DynamicType &&
        staticType is! InvalidType) {
      if (_isWhatClass(staticType, 'WhatVia')) return true;
    }
    if (unwrapped is SimpleIdentifier && unwrapped.name == 'via') {
      return true;
    }
    return false;
  }

  /// Returns `true` if the method declaration matches `WhatWidget.build(BuildContext context, WhatVia via)`.
  static bool isWhatWidgetBuildMethod(MethodDeclaration method) {
    if (method.name.lexeme != 'build') return false;
    final params = method.parameters?.parameters;
    if (params == null || params.length < 2) return false;

    // Check if second parameter is WhatVia
    return isWhatViaParameter(params[1]);
  }

  /// Returns `true` if the [node] is physically enclosed inside a `WhatVia` manifest scope
  /// (`WhatWidget.build`, `computed`, `composed`, `switched`, `Effect`, or closure with `via` parameter).
  static bool isInsideWhatViaScope(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      // 1. WhatWidget.build(context, via)
      if (current is MethodDeclaration && isWhatWidgetBuildMethod(current)) {
        return true;
      }

      // 4. Closures with a parameter typed 'WhatVia' or named 'via'
      if (current is FunctionExpression) {
        final params = current.parameters?.parameters;
        if (params != null && params.any(isWhatViaParameter)) {
          return true;
        }
      }

      current = current.parent;
    }
    return false;
  }

  // ===========================================================================
  // Callback & Dispatcher AST Patterns
  // ===========================================================================

  /// Checks if the parameter name corresponds to an event callback (e.g. onPressed, onTap).
  static bool isEventCallbackParameter(String name) {
    return name.startsWith(
            'on') || // onPressed, onTap, onChanged, onSubmitted, etc.
        name == 'listener' ||
        name == 'callback' ||
        name == 'action';
  }

  static const _terminalCallbackMethods = {
    'effect',
    'handled',
    'throttle',
    'debounce',
  };

  static const _terminalConstructors = {
    'Effect',
    'ThrottleEffect',
    'DebounceEffect',
    'EffectRunner',
    'WhatListener',
    'UnaryWhatListener',
  };

  /// Returns `true` if the [node] represents an invocation or instantiation of a reactive terminal, effect, or listener.
  static bool isTerminalOrEffectInvocation(AstNode node) {
    if (node is MethodInvocation) {
      if (_terminalCallbackMethods.contains(node.methodName.name)) {
        return true;
      }
    }
    if (node is FunctionExpressionInvocation) {
      final func = node.function;
      String? name;
      if (func is SimpleIdentifier) {
        name = func.name;
      } else if (func is PrefixedIdentifier) {
        name = func.identifier.name;
      } else if (func is PropertyAccess) {
        name = func.propertyName.name;
      }
      if (name != null && _terminalCallbackMethods.contains(name)) {
        return true;
      }
    }
    if (node is InstanceCreationExpression) {
      final typeName = node.constructorName.type.name.lexeme;
      if (_terminalConstructors.contains(typeName)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if the [node] represents an asynchronous timer or dispatcher invocation
  /// (e.g., Timer.run, scheduleMicrotask, Future.microtask, future.then).
  static bool isAsyncOrTimerInvocation(MethodInvocation node) {
    final name = node.methodName.name;

    // Top-level async dispatcher in dart:async
    if (name == 'scheduleMicrotask') {
      return true;
    }

    final target = node.target;
    if (target != null) {
      final targetSource = target.toSource();
      // Only accept 'run' if called on Timer (e.g. Timer.run or async.Timer.run)
      if (name == 'run' && targetSource.endsWith('Timer')) {
        return true;
      }
      // Delayed invocations: Future.delayed or Timer.delayed
      if (name == 'delayed' &&
          (targetSource.endsWith('Future') || targetSource.endsWith('Timer'))) {
        return true;
      }
      // Microtask invocation: Future.microtask
      if (name == 'microtask' && targetSource.endsWith('Future')) {
        return true;
      }
      // Future chaining: future.then, future.catchError, future.whenComplete
      if (name == 'then' || name == 'catchError' || name == 'whenComplete') {
        final targetType = target.staticType;
        if (targetType == null ||
            targetType is DynamicType ||
            targetType is InvalidType) {
          // Fallback for unresolved ASTs or dynamic receivers
          return true;
        }
        final elementName = targetType.element?.name;
        if (elementName == 'Future' ||
            elementName == 'FutureOr' ||
            elementName == 'Completer') {
          return true;
        }
        if (targetType is InterfaceType) {
          return targetType.allSupertypes
              .any((t) => t.element.name == 'Future');
        }
        return false;
      }
    }

    return false;
  }
}
