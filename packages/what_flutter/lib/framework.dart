// Copyright 2023-2026 Youngjune Jeon All rights reserved.
// Use of this source code is governed by an Apache 2.0 license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
///
/// Core framework library integrating What reactive topologies with Flutter elements and widgets.
///
/// Coordinates internal framework parts integrating What's 2-Phase LPDAG reactive engine with
/// Flutter element mixins, widget composition functors, durable animation engines,
/// and ticker schedulers.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:what/what.dart';
import 'package:what/effect.dart';

export 'package:what/what.dart';
export 'package:what/effect.dart';

// Framework Widgets
part 'src/widgets/_internal/_framework.dart';
part 'src/widgets/_internal/_composed.dart';
part 'src/widgets/_internal/_inline.dart';
part 'src/widgets/_internal/_listener.dart';
part 'src/widgets/composed.dart';
part 'src/widgets/framework.dart';
part 'src/widgets/inline.dart';
part 'src/widgets/async.dart';
part 'src/widgets/listener.dart';
part 'src/widgets/editable_text.dart';
part 'src/widgets/provider.dart';

// Framework Animation
part 'src/animation/durable/controller.dart';
part 'src/animation/durable/_internal/_proxy.dart';
part 'src/animation/durable/_internal/_staged_motion.dart';
part 'src/animation/durable/_internal/_simulation.dart';
part 'src/animation/durable/_internal/_delegate.dart';
part 'src/animation/durable/_internal/_controller.dart';
part 'src/animation/durable/_internal/_mixin.dart';

// Framework Foundation & Scheduler
part 'src/foundation/change_notifier.dart';
part 'src/foundation/_internal/_change_notifier.dart';
part 'src/scheduler/_internal/_ticker.dart';
part 'src/scheduler/ticker.dart';
