/**
 * A demonstration of how to use the datastore to provide
 * cloud file storage.
 */
library example.file_storage;

import 'dart:io' as io;
import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:googleclouddatastore/datastore.dart';

/**
 * Unindexed blob properties in the datastore are limited to
 * a maximum size (in bytes) of `1MB`.
 */
const int MAX_PART_SIZE = 1024 * 1024;

/**
 * An implementation of a simple file type object implementing storage of arbitrary sized blobs
 * of data in the datastore.
 */
@Kind()
class File extends Entity {
  /**
   * Adds all the file parts to the datastore, and returns a 
   * [Future] which completes when all parts have been added
   * successfully.
   */
  static Future _getParts(
      Datastore datastore, 
      io.RandomAccessFile file,
      int partId, //The id of the given file.
      int filePos, //The position in the file at which the 
      Key fileKey,
      int fileLength) {
    if (filePos >= fileLength) {
     return new Future.value(null); 
    }
    var contentCompleter = new Completer<Uint8List>();
    Future<Uint8List> getContent = file.setPosition(filePos).then((file) {
      return file.read(MAX_PART_SIZE).then((bytes) {
        contentCompleter.complete(new Uint8List.fromList(bytes));
      });
    }).catchError(contentCompleter.completeError);
    
    
    Completer completer = new Completer();
     getContent.then((content) {
      datastore.withTransaction((Transaction transaction) {
        transaction.insert.add(new FilePart(datastore, fileKey, filePos, content));
      }).then((committedTransaction) {
        var newPos = filePos + content.lengthInBytes;
        return _getParts(datastore, file, partId + 1, newPos, fileKey, fileLength)
            .catchError((err, stackTrace) {
              //If an error occurs when adding a subsequent part to the file
              //rollback the transaction.
              return committedTransaction.rollback()
                  .then((transaction) {
                    completer.completeError(err, stackTrace);
                  });
            });
      });
    });
    return completer.future;
  }
  
  static Future _splitFile(Datastore datastore, io.File ioFile, Key fileKey, int length) {
    return ioFile.open(mode: io.FileMode.READ)
        .then((openFile) {
          return _getParts(datastore, openFile, 0, 0, fileKey, length);
        });
  }
  
  /**
   * Create a new datastore file from a file in the filesystem. 
   */
  static Future<File> fromIoFile(Datastore datastore, io.File ioFile, String descriptor) {
    //Get a top-level datastore id for the file.
    return datastore.allocateKey("File").then((Key fileKey) {
      return ioFile.length().then((fileLength) {
        var file = new File._(datastore, fileKey, fileDescriptor: descriptor, sizeInBytes: fileLength);
        return datastore.withTransaction((Transaction transaction) {
          transaction.insert.add(file);
        }).then((Transaction committed) {
          return _splitFile(datastore, ioFile, fileKey, fileLength)
              .then((_) => file)
              .catchError((err, stackTrace) {
                committed.rollback();
                throw err;
              });
        });
      });
    });
  }
  
  @constructKind
  File._(Datastore datastore, Key key, {String fileDescriptor, int sizeInBytes}) : 
    super(datastore, key, {"descriptor" : fileDescriptor, "sizeInBytes" : sizeInBytes});
  
  @Property(indexed: true)
  String get path => getProperty("descriptor");
  void set path(String value) => setProperty("descriptor", value);
  
  @Property()
  int get sizeInBytes => getProperty("sizeInBytes");
  
  Stream<FilePart> getParts() {
    Query query = new Query(datastore.kindByName("FilePart"), new Filter.ancestorIs(key));
    return datastore.query(query).map((result) => result.entity);
  }
  
  /**
   * Reconstructs the file and write the result as the content to the end
   * of the given file.
   */
  Future writeToFile(io.File ioFile) {
    Future writeParts(List<FilePart> parts) {
      if (parts.isEmpty)
        return new Future.value();
      var part = parts.removeAt(0);
      return ioFile.open(mode: io.FileMode.APPEND)
        .then((file) => file.writeFrom(part.content))
        .then((_) => writeParts(parts));
      
    }
    return getParts().toList()
        .then((parts) {
          parts.sort();  
          return writeParts(parts);
        });
  }
}

@Kind()
class FilePart extends Entity implements Comparable<FilePart>{
  
  FilePart(Datastore datastore, Key fileKey, int partId, Uint8List content) :
    this._(
        datastore, 
        new Key("FilePart", parentKey: fileKey, name: "$partId"), 
        content: content);
  
  @constructKind
  FilePart._(Datastore datastore, Key key, {Uint8List content}) : 
    super(datastore, key, {'file_content' : content});
  
  //Not a property -- it is stored on the key
  int get filePos => int.parse(key.name);
  
  //Override the property type as 
  @Property(name: 'file_content')
  Uint8List get content => getProperty('file_content');
      
  int compareTo(FilePart other) => filePos.compareTo(other.filePos);
}