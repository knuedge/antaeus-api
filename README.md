Antaeus Web Service API
======================

About
-----
Antaeus is meant to be a web / cloud based management application for guest scheduling and check-ins. Antaeus is broken up into several components (backend, frontend, and workers). This component is the "backend" web service, and is meant to be used as 1) the API for communications from native clients, and 2) the backend used by a simpler but prettier web frontend.

This web service component __assumes__ communication happens via HTTPS, as transmission of secrets and authentication data, while perhaps obfuscated, happens in plain-text otherwise. This was chosen in lieu of a complicated authentication process largely to keep this backend component as simple as possible with as little dependencies on third-party components as possible, and to ensure maximum compatibility for clients. It is therefore the responsibility of the system administrator(s) deploying Antaeus to ensure it is behind an SSL proxy (Apache, nginx, etc.).

Installing
----------
The Anaeus Web Service API requires a Ruby runtime at least compatible with 2.0.x, such as JRuby or standard "Matz" Ruby 2.x or greater.

The `bundler` gem is required and the Gemfile is the authoritative source for required and known-compatible gem versions.

For persistence, the Antaeus Web Servce API uses [DataMapper](http://datamapper.org/) and is configured to work with [MySQL](http://dev.mysql.com/downloads/) version 5.x either using native libraries (C Ruby) or via JDBC (JRuby). Technically, any DB compatible with DataMapper should work, but MySQL is the only database tested or pre-configured to work. Steps for installing a database are beyond the scope of this document and can be found on the MySQL's site. It is also worth noting that there is no known compatibility issue with either MariaDB or Amazon's Aurora, so both should be supported (albeit not heavily tested).

Once the required gems are installed and the database software is running, a database and credentials must be setup for Antaeus. Instructions on how to create a database and credentials for accessing it very greatly depending on DB provider, so again, see the database vendor's site for those details.

To start the Antaeus Web Service API, either create a warfile using `warble war` and 1) run it directly with `java -jar antaeus-api.war` or 2) drop it in your favorite Java App Server (perhaps the well-tested [Apache Tomcat](http://tomcat.apache.org/)), or rather than using Java you can run the `main.rb` file using your favorite Ruby runtime. Simply running `rackup` in the applications root directory should work well.

On first run, a directory called ".antaeus" will be created under your home directory, and within it will be the config file: "api.yml". Antaeus should have automatically stopped, so feel free to edit the "api.yml" file to match your database, LDAP, and other configurations. After this step is complete, launch the Antaeus Web Service again and connect to it via the port described in the startup logs (usually 8080 when using a Java method or 4567 when using Ruby directly) to begin using it.

Currently, Antaeus only support LDAP for authentication and authorization. It uses a custom, limited-use, token-based API secret system for most API keys. Most actions require an API token, which can only be acquired via a call to `/users/authenticate.json`.

To acquire an API token, POST something similar the following JSON to `/users/authenticate.json`:

	{
		"login": "user@somedomain.com",
		"password": "letmein"
	}

Once you login, you will receive an API Key in the server's response to authenticate for all other actions requiring authentication. API Keys are only valid for one hour from the time of their last valid use.

The email and key are used to authenticate when passed as `X_API_EMAIL` and `X_API_KEY` HTTP Headers.

API Endpoint Documentation
--------------------------
TODO

License
-------
This stuff is released under the [Simplified BSD license](http://en.wikipedia.org/wiki/BSD_licenses#2-clause_license_.28.22Simplified_BSD_License.22_or_.22FreeBSD_License.22.29).