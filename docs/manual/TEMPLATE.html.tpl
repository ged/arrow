<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">

<!--

		Arrow Manual: (>>>title<<<)
		$Id: TEMPLATE.html.tpl,v 1.3 2003/12/20 20:19:24 stillflame Exp $

		Author:		(>>>USER_NAME<<<)

  -->

  <head>
	<title>Arrow Manual: (>>>title<<<)</title>

	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<meta http-equiv="Content-Script-Type" content="text/javascript" />

    <meta name="authors" content="(>>>USER_NAME<<<) ((>>>AUTHOR<<<))>" />
	<link rel="stylesheet" href="manual.css" type="text/css" />
  </head>
  <body>



	<!-- Experimental linkbox thingie -->
	<div id="linkbox">
	  <span id="linkbox-head">Arrow Manual</span>
	  <span id="linkbox-body">
		<ul>
		  <li>[<a href="index.html">Index</a>]</li>
		  <li>[<a href="whatis.html">What Is Arrow?</a>]</li>
		  <li>[<a href="download.html">Downloading</a>]</li>
		  <li>[<a href="install.html">Installation</a>]</li>
		  <li>[<a href="config.html">Configuration</a>]</li>
		  <li>[<a href="tutorial.html">Tutorial</a>]</li>
		  <li>[<a href="html/">API Reference</a>]</li>
		</ul>
	  </span>
	</div>

	<div id="content">
	  <h1>Arrow: (>>>title<<<)</h1>

	  <div class="section">
		<h2><a href="#(>>>POINT<<<)" id="(>>>MARK<<<)"></a></h2>
		<p></p>
	  </div>

	  <div class="section">
		<h2><a href="#bar" id="bar">Bar</a></h2>
		<p></p>
	  </div>
	</div>

  </body>
</html>


<!--
  Local Variables:
  mode: xml
 -->
