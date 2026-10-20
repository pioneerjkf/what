// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

part of '../../framework.dart';

final class _WhatUntrackedImpl implements WhatUntracked {
  const _WhatUntrackedImpl();

  @override
  @pragma('vm:prefer-inline')
  T call<T>(What<T> what) => what._read().data;

  @override
  @pragma('vm:prefer-inline')
  WhatState<T> state<T>(What<T> what) => what as WhatState<T>;
}
