MWURLOperation is a simple NSOperation subclass for performing a network operation. In the future it may include subclasses which handle OAuth support.

**NOTE: This class is not-yet production ready!**

Features
========

* Asynchronous loading of URL resources
* Completely self-contained object including the request and response
* Simple blocks-based callback APIs
* Background thread processing to keep your UI snappy
* Blocks-based content parsing based on the response's Content-Type (so you can snap in whatever JSON-parsing framework you like)

To Use
======

1. Import the class into your project
2. Create an instance for the URL you want to load
3. Set properties on it (e.g. GET/POST, body, headers, etc.)
4. Set a completion block on it, along with other callbacks (such as when an error is detected)
5. Add the operation to an NSOperationQueue
6. Query the operation for the response data in the completion block

Wish List
=========

* OAuth support (ideally a snap-in authentication system that supports multiple auth types)
* Automatic content parsers for XML, binary plists, images, etc.
* More easy-to-use configuration options (e.g. setUserAgent: or setEntityTag:, as opposed to setting those headers manually)
* Saving downloads directly to disk, being able to query for their data later, and file caching

License
=======

**tl;dr: It's the BSD license, so use it in whatever. Just drop me a line in your about box.**

Copyright (c) 2011, Mustacheware
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions  
are met:

Redistributions of source code must retain the above copyright  
notice, this list of conditions and the following disclaimer. 

Redistributions in binary form must reproduce the above copyright  
notice, this list of conditions and the following disclaimer in  
the documentation and/or other materials provided with the distribution. 

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS  
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT  
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS  
FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT  
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED  
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR  
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING  
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS  
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.