import 'connector_platform.dart';

/// Phones have the Connector app instead; XPENC itself stays offline.
ConnectorPlatform? createConnectorPlatform(String authUrl, String anonKey) =>
    null;
