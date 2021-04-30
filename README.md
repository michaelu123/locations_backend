# locations_backend (as of May 2021)

This will become a backend program for the data collected by the locations app (in repository locationsFlutter) stored on a server implemented by the repository LocationsServer.

I.e. the app collects data in the field, and stores them eventually in a central DB. LocationsServer provides a REST interface for the app, and stores the incoming data via Python/SQLAlchemy in a MySQL DB. 

This backend is meant to be used by a central authority (admin) that validates and consolidates the data provided by the app users, the contributors.

The app is programmed in Flutter and runs on Android and IOS.
The backend is also programmed in Flutter, but runs as a Windows program.
The intention is to reuse much code from the app in the backend.


