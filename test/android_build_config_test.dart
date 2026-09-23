import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every build dir is redirected before anything evaluates :app', () {
    // Ported from the Momentum twin, whose 1.6.0+28 never reached Google
    // Play: file_picker 13 brought the first plugin whose name sorts before
    // "app" (android_file_picker). With the buildDir assignment and
    // evaluationDependsOn(':app') in ONE subprojects block, that plugin forced
    // :app to evaluate before :app's buildDir was redirected, Flutter baked
    // the default R8 rules path under the stale android/app/build, R8 never
    // read its `-dontwarn androidx.**`, and `bundleRelease` failed on missing
    // androidx.window classes. Amber has no such plugin yet, so this was
    // latent here. Flutter's own template keeps two blocks for this reason.
    final gradle = File('android/build.gradle').readAsStringSync();
    final blocks = _subprojectsBlocks(gradle);

    final setsBuildDir = blocks.indexWhere((b) => b.contains('project.buildDir'));
    final dependsOnApp =
        blocks.indexWhere((b) => b.contains("evaluationDependsOn(':app')"));

    expect(setsBuildDir, isNonNegative, reason: 'no subprojects block redirects buildDir');
    expect(dependsOnApp, isNonNegative, reason: "no subprojects block depends on ':app'");
    expect(setsBuildDir, lessThan(dependsOnApp),
        reason: "buildDir must be set in an earlier subprojects block than evaluationDependsOn(':app')");
  });
}

/// The body of every top-level `subprojects { ... }` block, in file order.
/// Counts braces rather than using a regex: the bodies contain `${...}`.
List<String> _subprojectsBlocks(String gradle) {
  final blocks = <String>[];
  for (final m in RegExp(r'subprojects\s*\{').allMatches(gradle)) {
    var depth = 1;
    var i = m.end;
    while (i < gradle.length && depth > 0) {
      if (gradle[i] == '{') depth++;
      if (gradle[i] == '}') depth--;
      i++;
    }
    blocks.add(gradle.substring(m.end, i - 1));
  }
  return blocks;
}
