"use strict";
var fs = require( "fs" );
var path = require( "path" );
var sys = require( "lodash" );

var probe = require( "../probe" );

var data;

exports[ "Open test data file" ] = function ( test ) {
	test.expect( 1 );
	fs.readFile( path.resolve( __dirname, "./test.data.json" ), 'utf8', function ( err, d ) {
		test.ifError( err );

		data = JSON.parse( d );

		test.done();
	} );
};


exports["test bind to"] = function(test){
	var bound =probe.bindTo(data);


	var results = bound.find( {categories : "cat1"} );

	var compare = sys.select( data, function ( val ) {
		return sys.indexOf( val.categories, "cat1" ) > -1;
	} );

	test.deepEqual( results, compare );
	test.done();

};

exports["test mix to"] = function(test){
	probe.mixTo(data);


	var results = data.find( {categories : "cat1"} );

	var compare = sys.select( data, function ( val ) {
		return sys.indexOf( val.categories, "cat1" ) > -1;
	} );

	test.deepEqual( results, compare );
	test.done();

};
