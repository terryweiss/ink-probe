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

//exports["fix data"] = function ( test ) {
//	test.expect( 1 )
//
//	sys.each( data, function ( val ) {
//		val.age = sys.random( 18, 75 );
//		val.attr = sys.times( sys.random( 1, 10 ), function () {
//			var c = ["red", "green", "blue", "orange", "brown", "black", "white"];
//			var h = ["right", "left", "both"];
//			return {
//				color : c[sys.random( 0, c.length - 1 )],
//				hand  : h[sys.random( 0, h.length - 1 )]
//			}
//		} );
//	} );
//	fs.writeFile( path.resolve( __dirname, "./test.data.json" ), JSON.stringify( data, null, 4 ), {encoding : 'utf8'}, function ( err ) {
//		test.ifError( err );
//		test.done();
//	} );
//
//}

exports["test $eq"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"name.first" : {$eq : "Sheryl"}} );

	var compare = sys.select( data, function ( val ) {
		return val.name.first === "Sheryl";
	} );

	test.deepEqual( results, compare );
	test.done();
};

exports["test $neq"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"name.first" : {$ne : "Sheryl"}} );

	var compare = sys.select( data, function ( val ) {
		return val.name.first !== "Sheryl";
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test implied $eq"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"name.first" : "James"} );
	var compare = sys.select( data, function ( val ) {
		return val.name.first === "James";
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $all"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"categories" : {$all : ["cat4", "cat2", "cat1"]}} );
	var compare = sys.select( data, function ( record ) {
		var inter = sys.intersection( ["cat4", "cat2", "cat1"], record.categories );

		return inter.length === 3;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $gt"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$gt : 24}} );
	var compare = sys.select( data, function ( val ) {
		return val.age > 24;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $gte"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$gte : 50}} );
	var compare = sys.select( data, function ( val ) {
		return val.age >= 50;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $lt"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$lt : 24}} );
	var compare = sys.select( data, function ( val ) {
		return val.age < 24;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $lte"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$lte : 50}} );
	var compare = sys.select( data, function ( val ) {
		return val.age <= 50;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $in"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$in : [24, 28, 60]}} );

	var compare = sys.select( data, function ( val ) {
		return val.age === 24 || val.age === 28 || val.age === 60;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $nin"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$nin : [24, 28, 60]}} );
	var compare = sys.select( data, function ( val ) {
		return val.age !== 24 && val.age !== 28 && val.age !== 60;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $exists"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"name.middle" : {$exists : true}} );

	var compare = sys.select( data, function ( val ) {
		return val.name.middle;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $mod"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"age" : {$mod : [2, 0]}} );
	var compare = sys.select( data, function ( val ) {
		return val.age % 2 === 0;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $size"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {attr : {$size : 3}} );
	var compare = sys.select( data, function ( val ) {
		return sys.size( val.attr ) === 3;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $regex"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {"name.first" : {$regex : "m*", $options : "i"}} );
	var r = new RegExp( "m*", "i" );

	var compare = sys.select( data, function ( val ) {
		return r.test( val.name.first );
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $elemMatch"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {attr : {$elemMatch : [
		{color : "red", "hand" : "left"}
	]}} );

	var compare = sys.select( data, function ( val ) {
		return sys.select( val.attr,function ( inner ) {
			return inner.color === "red" && inner.hand === "left";
		} ).length > 0;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $and"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {$and : [
		{"name.first" : "Mildred"},
		{"name.last" : "Graves"}
	]} );

	var compare = sys.select( data, function ( val ) {
		return val.name.first === "Mildred" && val.name.last === "Graves";
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $or"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {$or : [
		{"age" : {$in : [24, 28, 60]}},
		{categories : "cat1"}
	]} );

	var compare = sys.select( data, function ( val ) {
		return val.age === 24 || val.age === 28 || val.age === 60 || sys.indexOf( val.categories, "cat1" ) > -1;
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $nor"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {$nor : [
		{"age" : {$in : [24, 28, 60]}},
		{categories : "cat1"}
	]} );

	var compare = sys.select( data, function ( val ) {
		return !(val.age === 24 || val.age === 28 || val.age === 60 || sys.indexOf( val.categories, "cat1" ) > -1);
	} );
	test.deepEqual( results, compare );
	test.done();
};

exports["test $not"] = function ( test ) {
	test.expect( 1 );
	var results = probe.find( data, {$not : {"age" : {$lt : 24}}} );

	var compare = sys.select( data, function ( val ) {
		return val.age >= 24;
	} );
	test.deepEqual( results, compare );
	test.done();
};
var expressions = {
	"implied eq" : {"name.first" : "James"},
	"$eq"        : {"name.first" : {$eq : "Sheryl"}},
	"$all"       : {"categories" : {$all : ["cat4", "cat2", "cat1"]}},
	"$gt"        : {"age" : {$gt : 24}},
	"$gte"       : {"age" : {$gte : 50}},
	"$in"        : {"age" : {$in : [24, 28, 60]}},
	"$lt"        : {"age" : {$lt : 24}},
	"$lte"       : {"age" : {$lte : 50}},
	"$ne"        : {"name.last" : {$ne : "Graves"}},
	"$nin"       : {"age" : {$nin : [24, 28, 60]}},
	"$exists"    : {"name.middle" : {$exists : true}},
	"$mod"       : {age : {$mod : [2, 0]}},
	"$size"      : {attr : {$size : 3}},
	"$regex"     : {"name.first" : {$regex : "m*", $options : "i"}},
	"$and"       : {$and : [
		{"name.first" : "Mildred"},
		{"name.last" : "Graves"}
	]},
	"$nor"       : {$nor : [
		{"age" : {$in : [24, 28, 60]}},
		{categories : "cat1"}
	]},
	"$not"       : {$not : {"age" : {$lt : 24}}},
	"$or"        : {$or : [
		{"age" : {$in : [24, 28, 60]}},
		{categories : "cat1"}
	]},

	"$elemMatch" : {attr : {$elemMatch : [
		{color : "red", "hand" : "left"}
	]}}

};

