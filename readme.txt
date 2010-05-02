LICENSE 
Copyright 2010 Marcos Placona - http://www.placona.co.uk

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.


Mango2Wordpress
Project Homepage:
http://www.placona.co.uk/projects/mango2wordpress


Installation Instructions:
	This instructions presume you already have databases and structures for both Mango Blog and Wordpress
	Extract all files to a publicly accesible directory on your CFML server.
	Create 2 DSN entries on your preferred ColdFusion engine:
		- one for Mango Blog
		- one for Wordpress
	Edit the file runner.cfm with your new dsn's
	Navigate to runner.cfm
	Enjoy your shiny wordpress blog  

History
	-v1.0
		- initial release
		- posts support
		- full category support
		- comments support
		- batch migration support


Features:
	- Migrates posts, categories and comments from a Mango Blog install to a Wordpress install.

Known Limitations:
	
	- Does not migrate images or assets

How can I help?
	- contribute with improvements and feature updates 
	- donate via PayPal to help maintain placona.co.uk (marcos.placona@gmail.com)