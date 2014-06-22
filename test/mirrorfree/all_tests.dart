/**
 * Tests the mirror-free version of the library.
 */
library mirrorfree_tests;

import 'package:unittest/unittest.dart';

import 'basic_test.dart' as basic;
import 'datastore_test.dart' as datastore;
import 'lookup_test.dart' as lookup;
import 'mutation_test.dart' as mutation;
import 'query_test.dart' as query;
import 'subtyping_test.dart' as subtyping;

void main() {
  group("mirrorfree", () {
    basic.main();
    datastore.main();
    lookup.main();
    mutation.main();
    query.main();
    subtyping.main();
  });
}