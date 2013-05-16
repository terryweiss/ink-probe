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

exports["test find"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {categories : "cat1"} );

	var compare = sys.select( data, function ( val ) {
		return sys.indexOf( val.categories, "cat1" ) > -1;
	} );

	test.deepEqual( results, compare );
	test.done();
};

exports["test find one"] = function ( test ) {
	test.expect( 1 );
	var results = probe.findOne( data, {categories : "cat5"} );

	test.equal( sys.indexOf( results.categories, "cat5" ) > -1, true );

	test.done();
};

exports["test remove"] = function ( test ) {
//	test.expect( 1 );
	var results = probe.remove( data, {attr : {$elemMatch : [
		{"hand" : "left"}
	]}} );

	sys.each( results, function ( val ) {
		sys.each( val.attr, function ( attr ) {
			if ( attr.hand === "left" ) {test.ok( false, JSON.stringify( attr ) );}
		} );
	} );

	test.done();
};

exports["test boolean all"] = function ( test ) {
	test.expect( 2 );
	var results = probe.all( data, {"name.first" : {$exists : true}} );
	test.deepEqual( results, true );
	results = probe.all( data, {"name.fred" : {$exists : true}} );
	test.deepEqual( results, false );

	test.done();
};

exports["test boolean any"] = function ( test ) {
	test.expect( 2 );
	var results = probe.any( data, {"categories" : "cat1"} );
	test.deepEqual( results, true );
	results = probe.any( data, {"categories" : "catfinger"} );
	test.deepEqual( results, false );

	test.done();
};


