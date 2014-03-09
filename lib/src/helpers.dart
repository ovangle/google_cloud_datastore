library helpers;

import 'dart:io';

import 'package:logging/logging.dart';

import 'connection.dart' as connection;

final logger = new Logger('datastore');
/**
 * Try to retrieve the values for the `DATASTORE_*` environment variables.
 *
 * Try and fallback on the following credentials in order:
 * - Compute Engine service acount
 * - Google APIs Signed JWT credentials based on
 * `DATASTORE_SERVICE_ACCOUNT` and `DATASTORE_PRIVATE_KEY_FILE`
 * envirnoment variables
 * - No credentials (development server)

Credentials getCredentialsFromEnv() {
  try {
    credentials = gce.AppAssertionCredentials(connection.API_SCOPE);
    credentials.authorize();
    // Force credentials to refresh to detect if we are running
    // on compute engine
    return credentials.refresh().then((credentials) {
      logger.info('connect using compute credentials');
      return credentials
    })
    .catchError((e) {
      if (e is client.AccessTokenRefreshException || e is HttpException) {
        var env = Platform.environment;
        if (env.containsKey('DATASTORE_SERVICE_ACCOUNT') && env.containsKey('DATASTORE__PRIVATE_KEY_FILE')) {
          new File(env['DATASTORE_PRIVATE_KEY_FILE'])
              .openRead().toList()
              .then((bytes) {
                var credentials = client.SignedJWTAsertionCredentials(
                    env['DATASTORE_SERVICE_ACOUNT'], bytes, connection.API_SCOPE);
                logger.fine('Connect using DatastoreSignedJwtCredentials');
                return credentials;
              });
        } else {
          logger.info("Connect using no credentials");
          return null;
        }
      }
    });

}
*/

