enum WebEntryAction {
  login,
  register,
  test;

  static WebEntryAction? fromUri(Uri uri) {
    final value = uri.queryParameters['action']?.trim().toLowerCase();

    return switch (value) {
      'login' => WebEntryAction.login,
      'register' => WebEntryAction.register,
      'test' => WebEntryAction.test,
      _ => null,
    };
  }

  static Uri withoutAction(Uri uri) {
    final queryParameters = <String, dynamic>{
      for (final entry in uri.queryParametersAll.entries)
        entry.key: List<String>.from(entry.value),
    }..remove('action');

    return Uri(
      scheme: uri.scheme.isEmpty ? null : uri.scheme,
      userInfo: uri.hasAuthority ? uri.userInfo : null,
      host: uri.hasAuthority ? uri.host : null,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
      fragment: uri.hasFragment ? uri.fragment : null,
    );
  }
}
