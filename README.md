# Google cloud datastore #

A protobuffer based console client for the google cloud datastore

## Install ##

To run a datastore instance, the python library [datastore_server][]
must be installed and running on the local machine. Requests
are forwarded via the server to the datastore server in accordance
with the specifications of the forwarding server.

When the [oauth2] library is upgraded to support connecting to compute
engine instances via service accounts, this library will be updated
to support the workflow

[datastore_server][https://github.com/ovangle/datastore_server]