# Google cloud datastore #


## Overview ##

A protobuffer backed library for interacting with [google cloud datastore][1] and handles connections, authentication and provides a simple framework for interacting with the datastore.

Two methods for interacting with the datastore are offered by the library. In addition to the mirrors based `datastore.dart` library, which can be used for persistence of regular dart classes,  direct access to the datastore protobuffer API (generated using the dart [protobuf][2] package) is also available and can be accessed via a `DatastoreConnection` instance. 

## Usage ##

Include the datastore library in your `pubspec.yaml` file:

    dependencies:
      google_cloud_datastore: any
      
The packages exposes two APIs, the `datastore` API, which provides a mechanism for defining persistent objects based on standard dart class definitions and provides utility methods for interacting with the datastore. To use this library, import the `datastore` library from the root of the `package`

    import 'package:google_cloud_datastore/datastore.dart';
    
A minimal library which provides access to the raw protobuffer API (which is generated directly from the [datastore protobuffer API schema][6]) and to the `DatastoreConnection` instance is avialable vial the `datastore.protobuf` library.

    import 'package:google_cloud_datastore/datastore_protobuf.dart';
    
### Connections ###
      
The main connection to the datastore is available via an instance of the `DatastoreConnection` object. In order to access the datastore from a compute engine, it is assumed that you have enabled the `Google Cloud Datastore API` using the [google developer console][5] and either:

- you are connected to a compute engine instance with the `datastore` and `userinfo.email` scopes
- You have a valid service account and associated private key file with which to connect to the datastore instance.
- You can make http requests to an instance of the [gcd][3] tool.

#### Connect from compute engine instance ####

If connecting to the datastore from an instance of the compute engine, the `DatastoreConnection` object simply needs to be instantiated using the `datasetId` of the target datastore.

	Future<DatastoreConnection> connection = 
		DatastoreConnection.open(<dataset_id>, projectNumber: <project_number>);

#### Connect using service account ####

If connecting to the datastore using a service acount and key file, these can be passed into the constructor by specifying the service account name (the email of the service account) and a private key file (which is obtained by creating an instance of the service account).

The private key file needs to be in a `.pem` format, which can be obtained from the `.p12` file supplied from google using the command
    
    openssl pkcs12 -in <privatekey>.p12 -nocerts \
         -passin pass:notasecret -nodes -out <rsa_private_key>.pem

If asked for the import password, the password will be `notasecret`.

The datastore can then be instantiated with the details of the service account.

    Future<DatastoreConnection> connection = DatastoreConnection.open(
    	"<dataset_id>",
    	projectNumber: "project_number",
    	serviceAccount: "<service_account_email>",
    	pathToPrivateKey: "<path_to_private_key>");
    	  
#### Connect to gcd tool ####

If connecting to a compute engine instance running at a given host, simply provide the datasetId and hostname to the `DatastoreConnection` instance.

    Future<DatastoreConnection> connection =  DatastoreConnection.open(
    	<dataset_id>, 		
    	host:<gcd_host>);

    
### Key concepts ###

#### Datastore ####

The `Datastore` negotiates communications over a `DatastoreConnection`. Providing utility methods for looking up, querying and mutating entities. Creating a `Datastore` object will automatically scan the local mirror system for `kinds` during construction. 

	final Datastore datastore = new Datastore(connection);
	
#### Kind ####

A `Kind` is a static definition of a datastore persistable object. 

A `Kind` must directly extend `Entity` and be annotated with the `@Kind` annotation. The datastore name of the kind can either be provided via the annotation or will be inferred from the name of the class.

A `Kind` must also provide a generative constructor which forwards to `Entity(Key key, [Map<String,dynamic> propertyInits])`

eg. The following class declaration a `Kind` with no properties which can be persisted as a `EmptyKind` object in the datastore.

    @Kind()
    class EmptyKind extends Entity {
    
    	@constructKind
    	EmptyKind._(Key key): super(key);
    }
    
The `Entity` constructor also accepts an (optional) map of property names to values, which can be used to provide initial values for entities during object construction.

#### Abstract Kinds ####

By default, all `Kind`s are `concrete`, which means that they are persisted as a datastore entity. To save duplicating code, it might be advantageous to create a single base kind holding properties applicable to multiple entity kinds.

This can be accomplished in a variety of ways.

- The first option is to not annotate the base kind , eg:

```
class BaseKind extends Entity {
  BaseKind(Key key): super(key);
  //Properties
}

@Kind()
class Subkind extends BaseKind {

   Subkind(Key key): super(key);
}
```

In this case, `Subkind` will inherit all properties of `BaseKind` and `BaseKind` can even be an `abstract` kind, disabling dart instantiation of the type.

- The second option is to create a `concrete` base kind and `abstract` subkinds. eg.

```
@Kind()
class BaseKind extends Entity {
  BaseKind(Key key): super(key);
  //Properties
}

@Kind(concrete: false)
class Subkind extends BaseKind {
  Subkind(Key key): super(key);
}
```

In this latter case, `Subkind` will, when persisted to the datastore, be stored as a `BaseKind` entity, but have an implicit `___subkind` property which associates it with the subclass definition.

This can be useful if you want to create multiple different kinds of entities with the same basic structure that can be accessed using the same query, without providing a lot of useless optional fields on `BaseKind`

For instance, if you had a datastore entity `Message` and you wanted to create a type of `Message` that was only visible to certain users, you could do:

```
@Kind()
class Message extends Entity {
  @Property()
  String content => getProperty('content');
} 

@Kind(concrete: False)
class PrivateMessage extends Message {
  /**
   * All `User`s who can view this message
   */ 
  @Property()
  List<Key> visibleTo => getProperty('visibleTo');
}
```

**NOTE:**
The use of abstract kinds is limited to the following limitations:

- Exactly one kind in an inheritance heirarchy can have `concrete: True`.
- `Key`s and `Query`s must be instantiated with the name of the `concrete` parent (so, you would pass `Key('BaseKind', ...)` into the above constructor).


#### Entity ####

An `entity` represents a persisted instance of a `kind` from the datastore.


#### Key ####

A `key` is a unique identifier of an entity in the datastore. A key is always bound to a particular `kind`
and may be `named` (in which case the unique identifier
is a user provided `String`), or `unnamed` (in which case the identifier is a database assigned `int`).

**NOTE:**
While named entities can be created directly, unnamed
entities (those with an `id`) need to be allocated in the datastore before they can be used
using the `datastore.allocateKey` method. 

A `key` is analagous to a file system path and represents a path from the root of the datastore 
to the location of the entity. An `entity` can *own* other entities, and queries within this 
group are guaranteed by the datastore to be strongly consistent.

#### Property ####

Every `Entity` is built from multiple `Property`s, which represent the data stored on the `Entity`. Properties can be any of the following dart types:

 - `int`
 - `double`
 - `num`*
 - `String`
 - `DateTime`
 - `Key`
 - `Uint8List`**
 - `dynamic` - *A value of any of the above types.*
   
Or a `List` of any of the above types.

\* *`num` values are stored as a `doubleValue` in the datastore.*<br />
\*\* *stored as a `blobValue` on the datastore entity. Note that a property typed as `List<int>` is to be a `List` of `intValue`, whereas `Uint8List` is stored as a `blobValue`.*

eg.

	@Kind()
	class MyKind extends Entity {
	  /**
	   * Get a new instance of `MyKind` with `propertyOne`
	   * initialised to the provided value
	   */
	  MyKind(Datastore datastore, Key key, {propertyOne: "hello"}): 
	    super(datastore, key, {"propertyOne" : propertyOne});
		
	  /**
	   * A `final` String property with name `"propertyOne"` which is stored as a `String` value
	   */
	  @Property()
	  String get propertyOne => getProperty("propertyOne");
		
	  /**
	   * A mutable `int` property with name `"property_two"` which is stored
	   */
	  @Property(name: "property_two", type: PropertyType.INTEGER)
	  dynamic get propertyTwo => get_property("property_two");
      set propertyTwo(dynamic value) => set_property("property_two");
	}



## Examples ##

### Connecting to the datastore ###

The [canonical example][4] provided for datastore connections is the `example/adams.dart` file.

A similar example demonstrating usage of the `protobuf` API is available as `example/adams_protobuf.dart`.

## Testing ##

Running the unit tests requires an instance of the [gcd tool][3] installed on the machine.

1. Create an instance of the tool using
    
    `bash gcd.sh create --datset_id='test-id`


2. Start the gcd server running on localhost port `5961` in `testing` mode.


    `bash gcd.sh start --port=5961 --testing ~/.gcd`

3. Run the unit tests in dart checked mode


    `dart -c test/all_tests.dart`


[1]: https://developers.google.com/datastore/
[2]: https://github.com/dart-lang/dart-protobuf
[3]: https://developers.google.com/datastore/docs/tools/
[4]: https://developers.google.com/datastore/docs/getstarted/start_python/
[5]: https://console.developers.google.com/
[6]: https://github.com/GoogleCloudPlatform/google-cloud-datastore/blob/v1beta2-rev1-2.1.0/proto/datastore_v1.proto
