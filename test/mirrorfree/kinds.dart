/**
 * Various kind definitions used in mirrofree tests.
 */
library mirrorfree_tests.kinds;

import '../../lib/src/common.dart';

final mirrorfreeKinds =
    [ User.userKind,
      UserDetails.userDetailsKind,
      File.fileKind,
      ProtectedFile.protectedFileKind
    ];

class User extends Entity {

  static final KindDefinition userKind =
      new KindDefinition("User",
          [ new PropertyDefinition("name", PropertyType.STRING, indexed: true),
            new PropertyDefinition("password", PropertyType.BLOB),
            new PropertyDefinition("user_details", PropertyType.KEY),
            new PropertyDefinition("date_joined", PropertyType.DATE_TIME),
            new PropertyDefinition("age", PropertyType.INTEGER, indexed: true),
            new PropertyDefinition("isAdmin", PropertyType.BOOLEAN),
            new PropertyDefinition("friends", PropertyType.LIST(PropertyType.KEY))
          ],
          entityFactory: (key) => new Entity(key)
      );

  User(Key key): super(key);
}

class UserDetails extends Entity {

  static final KindDefinition userDetailsKind =
      new KindDefinition(
          "UserDetails",
          [],
          entityFactory: (key) => new Entity(key)
  );

  UserDetails(Key key): super(key);
}

class File extends Entity {
  static KindDefinition fileKind =
      new KindDefinition("File",
          [ new PropertyDefinition("path", PropertyType.STRING, indexed: true) ],
          entityFactory: (key) => new File(key)
      );

  File(Key key, {propertyInits: const {}, subkind}): super(key, propertyInits, subkind);
}

class ProtectedFile extends File {
  static KindDefinition protectedFileKind =
      new KindDefinition("ProtectedFile",
          [ new PropertyDefinition("user", PropertyType.KEY, indexed: true),
            new PropertyDefinition("level", PropertyType.INTEGER, indexed: false)
          ],
          extendsKind: File.fileKind,
          entityFactory: (key) => new ProtectedFile(key),
          concrete: false
  );

  ProtectedFile(Key key):
    super(key, subkind: "ProtectedFile");

}
