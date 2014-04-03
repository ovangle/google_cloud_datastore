# Google cloud datastore #


## Overview ##

A protobuffer backed library for interacting with [google cloud datastore][1] and handles connections, authentication and provides a simple framework for interacting with the datastore.

Two methods for interacting with the datastore are offered by the library. In addition to the mirrors based `datastore.dart` library, which can be used for persistence of regular dart classes,  direct access to the datastore protobuffer API (generated using the dart [protobuf][2] package) is also available and can be accessed via a `DatastoreConnection` instance. 

## Usage ##

Include the datastore library in your `pubspec.yaml` file:

    dependencies:
      googleclouddatastore: '>=0.2.0'
      
The packages exposes two APIs, the `datastore` API, which provides a mechanism for defining persistent objects based on standard dart class definitions and provides utility methods for interacting with the datastore. To use this library, import the `datastore` library from the root of the `package`

    import 'package:googleclouddatastore/datastore.dart';
    
A minimal library which provides access to the raw protobuffer API (which is generated directly from the [datastore protobuffer API schema][6]) and to the `DatastoreConnection` instance is avialable vial the `datastore.protobuf` library.

    import 'package:googleclouddatastore/datastore_protobuf.dart';
    
### Connections ###
      
The main connection to the datastore is available via an instance of the `DatastoreConnection` object. In order to access the datastore from a compute engine, it is assumed that you have enabled the `Google Cloud Datastore API` using the [google developer console][5] and either:

- you are connected to a compute engine instance with the `datastore` and `userinfo.email` scopes
- You have a valid service account and associated private key file with which to connect to the datastore instance.
- You can make http requests to an instance of the [gcd][3] tool.

#### Connect from compute engine instance ####

If connecting to the datastore from an instance of the compute engine, the `DatastoreConnection` object simply needs to be instantiated using the `datasetId` of the target datastore.

	final DatastoreConnection connection = 
		new DatastoreConnection(<dataset_id>, projectNumber: <project_number>);

#### Connect using service account ####

If connecting to the datastore using a service acount and key file, these can be passed into the constructor by specifying the service account name (the email of the service account) and a private key file (which is obtained by creating an instance of the service account).

The private key file needs to be in a `.pem` format, which can be obtained from the `.p12` file supplied from google using the command
    
    openssl pkcs12 -in <privatekey>.p12 -nocerts \
         -passin pass:notasecret -nodes -out <rsa_private_key>.pem

If asked for the import password, the password will be `notasecret`.

The datastore can then be instantiated with the details of the service account.

    final DatastoreConnection connection = new DatastoreConnection(
    	"<dataset_id>",
    	projectNumber: "project_number",
    	serviceAccount: "<service_account_email>",
    	pathToPrivateKey: "<path_to_private_key>");
    	  
#### Connect to gcd tool ####

If connecting to a compute engine instance running at a given host, simply provide the datasetId and hostname to the `DatastoreConnection` instance.

    final DatastoreConnection connection = new DatastoreConnection(
    	<dataset_id>, 		
    	host:<gcd_host>);

    
### Key concepts ###

#### Datastore ####

The `Datastore` negotiates communications over a `DatastoreConnection`. Providing utility methods for looking up, querying and mutating entities. Creating a `Datastore` object will automatically scan the local mirror system for `kinds` during construction. 

	final Datastore datastore = new Datastore(connection);

**Note:** It is assumed that only **one** instance of the `Datastore` object is available to the application in it's lifetime.

#### Kind ####

A `kind` is a static definition of a datastore persistable object. 

A `kind` must directly extend `Entity` and be annotated with the `@kind` annotation. The datastore name of the kind can either be provided via the annotation or will be inferred from the name of the class.

A `kind` must also provide a generative constructor which forwards to `Entity(Datastore datastore, Key key, [Map<String,dynamic> propertyInits])`

eg. The following class declaration a `kind` with no properties which can be persisted as a `EmptyKind` object in the datastore.

    @kind()
    class EmptyKind extends Entity {
    
    	@constructKind
    	EmptyKind._(Datastore datastore, Key key):
    	    super(datastore, key);
    }
    
#### Entity ####

An `entity` represents a persisted instance of a `kind` from the datastore.


#### Key ####

A `key` is a unique identifier of an entity in the datastore. A key is always bound to a particular `kind`
and may be `named` (in which case the unique identifier
is a user provided `String`), or `unnamed` (in which case the identifier is a database assigned `int`).

While named entities can be created directly, unnamed
entities need to be allocated in the datastore before use 
using the `datastore.allocateKey` method.

A `key` is analagous to a file system path and represents a path from the root of the datastore 
to the location of the entity. An `entity` can *own* other entities, and queries within this 
group are guaranteed by the datastore to be strongly consistent. 

## Examples ##

### Connecting to the datastore ###

The [canonical example][4] provided for datastore connections is the `example/adams.dart` file.

### Filesystem storage ###

An additional example demonstrating how the cloud datastore can be used for storage of file-like objects see `example/file_storage.dart`.

For a more thorough implementation of file storage using the google cloud datastore, see the
related package, `cloud_filesystem`.  

## Limitiations ##

A `DatastoreConnection` object can presently only be used for connecting to the datastore from inside a compute engine instance or for connecting to an instance of a local [gcd][3] server.

Connecting to a remote production datastore instance via a google service account is not yet supported, but is planned for a future release.

[1]: https://developers.google.com/datastore/
[2]: https://github.com/dart-lang/dart-protobuf
[3]: https://developers.google.com/datastore/docs/tools/
[4]: https://developers.google.com/datastore/docs/getstarted/start_python/
[5]: https://console.developers.google.com/