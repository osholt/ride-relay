import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/services/basemap_configuration.dart';

void main() {
  const configuration = BasemapConfiguration(
    styleUrl: 'https://tiles.example.test/styles/liberty',
    darkStyleUrl: 'https://tiles.example.test/styles/dark',
    attribution: 'Example',
    maximumNativeZoom: 18,
  );

  test('forBrightness(dark: true) swaps in the dark style URL', () {
    final dark = configuration.forBrightness(dark: true);

    expect(dark.styleUrl, 'https://tiles.example.test/styles/dark');
    expect(dark.usesMapLibre, isTrue);
  });

  test('forBrightness(dark: false) leaves the configuration unchanged', () {
    final light = configuration.forBrightness(dark: false);

    expect(light.styleUrl, configuration.styleUrl);
    expect(identical(light, configuration), isTrue);
  });

  test('forBrightness(dark: true) is a no-op without a dark style URL', () {
    const noDarkStyle = BasemapConfiguration(
      styleUrl: 'https://tiles.example.test/styles/liberty',
      attribution: 'Example',
    );

    final resolved = noDarkStyle.forBrightness(dark: true);

    expect(resolved.styleUrl, noDarkStyle.styleUrl);
  });

  test('fromEnvironment defaults to the OpenFreeMap dark style', () {
    final environment = BasemapConfiguration.fromEnvironment();

    expect(
      environment.darkStyleUrl,
      'https://tiles.openfreemap.org/styles/dark',
    );
  });
}
