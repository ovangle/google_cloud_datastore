part of datastore.common;

typedef Completer<Transaction> _PendingTransaction(Transaction transaction);

class Transaction {
  /**
   * The datastore can only handle a single transaction at a time.
   */
  static final Queue<Completer<Transaction>> _transactionQueue = new Queue<Completer<Transaction>>();
  
  /**
   * The default timeout limit for pending transactions.
   */
  static Duration transactionTimeout = new Duration(milliseconds: 500);
  
  Datastore _datastore;
  final Uint8List _id;
  
  /**
   * The datastore assigned id of the datastore id, encoded as a 
   * hex string.
   */
  String get id => CryptoUtils.bytesToBase64(_id);
  
  bool _isCommitted = false;
  /**
   * `true` iff the transaction has been committed to the datastore.
   */
  bool get isCommitted => _isCommitted;
  
  bool _isRolledBack = false;
  /**
   * `true` iff the transaction has been committed and subsequently rolled back.
   */
  bool get isRolledBack => _isRolledBack;
  
  Logger get logger => _datastore.logger;
  
  
  /**
   * A list of entities which will be inserted into the 
   * datastore when the transaction is committed.
   */
  List<Entity> insert = new List<Entity>();
  
  /**
   * A list of entities which will be updated in the datastore
   * when the transaction is committed.
   */
  List<Entity> update = new List<Entity>();
  /**
   * A list of entities to upsert into the datastore when the
   * transaction is committed.
   * 
   * An upserted entity is inserted into the datastore if no
   * entity with a matching key already exists, otherwise
   * the matching entity is updated.
   */
  List<Entity> upsert = new List<Entity>();
  /**
   * A list of keys to delete from the datastore when the 
   * transaction is committed.
   */
  List<Key> delete = new List<Key>();
  
  List<Key> _insertedKeys = new List<Key>();
  /**
   * The keys which were inserted during the transaction.
   * Will be empty until the 
   */
  Iterable<Key> get insertedKeys => _insertedKeys;
  
  /**
   * Begin a new transaction against the 
   */
  
  static Future<Transaction> begin(Datastore datastore, {dynamic onTimeout()}) {
    Completer<Transaction> pendingTransaction = new Completer<Transaction>();
    _transactionQueue.addLast(pendingTransaction);
    _runNextTransaction(datastore);
    return pendingTransaction.future
        .timeout(transactionTimeout, onTimeout: onTimeout);
  }
  
  static void _runNextTransaction(Datastore datastore) {
    if (_transactionQueue.isEmpty)
      return;
    Completer<Transaction> pending = _transactionQueue.removeFirst();
    var request = new schema.BeginTransactionRequest();
    datastore.connection.beginTransaction(request)
        .then((response) {
          var transactionId = new Uint8List.fromList(response.transaction);          
          var transaction = new Transaction._(datastore, transactionId);
          datastore.logger.info("Running transaction (${transaction.id})");
          pending.complete(transaction);
        });
  }
  
  Transaction._(Datastore this._datastore, Uint8List this._id);
  
  /**
   * Commit the transaction to the datastore.
   */
  Future<Transaction> commit() {
    if (isCommitted) {
      return new Future.error(new StateError("Transaction already committed"));
    }
    schema.CommitRequest commitRequest = new schema.CommitRequest()
      ..mutation = _toSchemaMutation()
      ..transaction.addAll(_id);
    
    _datastore.logger.info("Committing transaction (${id})");
    return _datastore.connection
        .commit(commitRequest)
        .then((commitResponse) {
          logger.info("Commit response received");
          _isCommitted = true;
          schema.MutationResult mutationResult = commitResponse.mutationResult;
          _datastore.logger.info("Transaction committed with ${commitResponse.mutationResult.indexUpdates} index updates");
          _insertedKeys.addAll(
              mutationResult.insertAutoIdKey
                  .map((schemaKey) => new Key._fromSchemaKey(schemaKey))
          );
          return this;
        })
        .catchError((err, stackTrace) {
          logger.severe("Commit request failed", err, stackTrace);
        })
        .whenComplete(() => _runNextTransaction(_datastore));
  }
  
  /**
   * Rollback the [Transaction] in the datastore.
   */
  Future<Transaction> rollback() {
    if (!isCommitted)
      return new Future.error(new StateError("Nothing to rollback: Transaction not yet committed"));
    schema.RollbackRequest rollbackRequest = new schema.RollbackRequest()
        ..transaction.addAll(_id);
    return _datastore.connection
        .rollback(rollbackRequest)
        .then((rollbackResponse) {
          _isRolledBack = true;
          return this;
        });
  }
  
  schema.Mutation _toSchemaMutation() {
    Iterable insertAutoId = insert.where((ent) => ent.key.name == null);
    Iterable insertNoAutoId = insert.where((ent) => ent.key.name != null);
    return new schema.Mutation()
      ..insert.addAll(insertNoAutoId.map((ent) => ent._toSchemaEntity()))
      ..insertAutoId.addAll(insertAutoId.map((ent) => ent._toSchemaEntity()))
      ..upsert.addAll(upsert.map((ent) => ent._toSchemaEntity()))
      ..update.addAll(update.map((ent) => ent._toSchemaEntity()))
      ..delete.addAll(delete.map((k) => k._toSchemaKey()));
  }
}