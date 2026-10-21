import 'package:what/effect.dart';
import 'package:what_extensions/what_extensions.dart';

void main() async {
  // 1. Create a reactive controller holding a collection of numbers
  final numbersController = WhatController<List<double>>([10.0, 20.0, 30.0]);

  // 2. Use what_extensions to calculate reactive sum and average
  final sumWhat = numbersController.what.elements.sum;
  final avgWhat = numbersController.what.elements.average;

  // 3. Actively observe collection aggregations using EffectRunner
  final sumRunner =
      sumWhat.effect(() => print('Sum: ${untracked(sumWhat)}')).run();
  final avgRunner =
      avgWhat.effect(() => print('Average: ${untracked(avgWhat)}')).run();

  // 4. Update collection reactively
  numbersController.set([5.0, 15.0, 25.0, 35.0]);

  // 5. Await microtask flush
  await Future<void>.delayed(Duration.zero);

  // 6. Cleanup
  sumRunner.deactivate();
  avgRunner.deactivate();
}
