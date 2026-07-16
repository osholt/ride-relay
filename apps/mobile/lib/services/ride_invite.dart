class RideInvite {
  const RideInvite({
    required this.rideId,
    required this.rideCode,
    required this.secret,
  });

  final String rideId;
  final String rideCode;
  final String secret;

  Uri get uri => Uri(
    scheme: 'riderelay',
    host: 'join',
    queryParameters: {'ride': rideId, 'code': rideCode, 'secret': secret},
  );

  static RideInvite? tryParse(String input) {
    final match = RegExp(
      r'riderelay://[^\s]+',
      caseSensitive: false,
    ).firstMatch(input.trim());
    final candidate = match?.group(0) ?? input.trim();
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'riderelay' ||
        uri.host.toLowerCase() != 'join') {
      return null;
    }

    final rideId = uri.queryParameters['ride']?.trim() ?? '';
    final rideCode = uri.queryParameters['code']?.trim().toUpperCase() ?? '';
    final secret = uri.queryParameters['secret'] ?? '';
    if (rideId.isEmpty ||
        rideId.length > 128 ||
        !RegExp(
          r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
        ).hasMatch(rideCode) ||
        secret.length < 16 ||
        secret.length > 512) {
      return null;
    }
    return RideInvite(rideId: rideId, rideCode: rideCode, secret: secret);
  }
}
