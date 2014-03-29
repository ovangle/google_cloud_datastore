# Google cloud datastore #


## Overview ##

A protobuffer backed library for interacting with [google cloud datastore][1] and handles connections, authentication and provides a simple framework for interacting with the datastore.

Two methods for interacting with the datastore are offered by the library. In addition to the mirrors based `datastore.dart` library, which can be used for persistence of regular dart classes,  direct access to the datastore protobuffer API (generated using the dart [protobuf][2] package) is also available and can be accessed via a `DatastoreConnection` instance. 

## Usage ##

Include the datastore library in your `pubspec.yaml` file:

    dependencies:
      googleclouddatastore: '>=0.1.0'
      
A new connection to the datastore can be created using a `DatastoreConnection` object. The `clientId` should be the 

    import 
    
### Key concepts ###

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

An `Entity` is an instance of a kind. There are two ways of constructing an entity.


#### Key ####

A `key` is a unique identifier of an entity in the datastore. A key is always bound to a particular `kind`
and may be `named` (in which case the unique identifier
is a user provided `String`), or `unnamed` (in which case the identifier is a database assigned `int`).

While named entities can be created directly, unnamed
entities need to be allocated in the datastore before use 
using the `datastore.allocateKey` method.

A `key` is analagous to a file system path and represents a path from the root of the datastore to the location of the entity. An `entity` can *own* other entities, and queries within this group are guaranteed by the datastore to be strongly consistent. 

## Examples ##

### Connecting to the datastore ###

The canonical example provided for datastore connections is the `adams` file. As well as providing 

### Unmodifiable Properties / Key paths ###

As an example, consider a file that is split up into multiple parts before insertion into the datastore (since datastore blob properties have a maximum size of `1MB`).

    @kind
    class File extends Entity {
    	/**
    	 * Create a new file with the given `fileName` in the datastore.
    	 * `fileName` is assumed to be unique in the datastore.
    	 */
        File(Datastore datastore, String fileName) :
        	this(datastore, new Key("File", null, name: fileName));
        
        @constructKind
        File(Datastore datastore, Key key) : 
           super(datastore, key);
  	    
  	    //File names are unique in the datastore, so we can use them
  	    //as the file id.
        String get fileName => key.name;
        
        Future<List<FilePart>> fileParts() {
        	Query query = new Query.ancestorIs(new Key.fromKey(this.key))
        		..sortBy('FilePart.__key__');
        	return datastore.runQuery(query).toList()
        }
   	}
   	
   	@kind()
   	class FilePart extends Entity {
   		FilePart(Datastore datastore, File file, int fileId, Uint8List fileContent) :
   			this(datastore, file.getChild("FilePart", name: "$fileId"))
   		
   		@constructKind
   		FilePart._(Datastore datastore, Key key {Uint8List fileContent}) :
   			super(datastore, key);
   	
   		//File parts are unnamed. Ids will be allocated when splitting the file.
   		int partId => key.id;
   		
   		/**
   		 * The content of the file as a list of bytes.
   		 * After creation, file content should not be 
   		@property("file_content")
   		Uint8List get _content => getProperty("file_content")
   			.unmodifiable();
   	}

    

       

## Limitiations ##

A `DatastoreConnection` object can presently only be used for connecting to the datastore from inside a compute engine instance or for connecting to an instance of a local [gcd][3] server.

Connecting to a remote production datastore instance via a google service account is not yet supported, but is planned for a future release.

[1]: https://developers.google.com/datastore/
[2]: http://
[3]: http://gcd.instance