/**
 * Immutable hash set.
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module containers.immutablehashset;

/**
 * The immutable hash set is useful for constructing a read-only collection that
 * supports quickly determining if an element is present. Because the set does
 * not support inserting, it only takes up as much memory as is necessary to
 * contain the elements provided at construction.
 */
struct ImmutableHashSet(T, alias hashFunction)
{
	@disable this();
	@disable this(this);

	/**
	 * Constructs an immutable hash set from the given values. The values must
	 * not have any duplicates.
	 */
	this(const T[] values) immutable
	in
	{
		import std.algorithm;
		import std.array;
		assert (values.dup.sort.uniq.array.length == values.length);
	}
	body
	{
		import std.stdio;
		empty = values.length == 0;
		length = values.length;
		if (empty)
			return;
		immutable float a = (cast(float) values.length) / .75f;
		size_t bucketCount = 1;
		while (bucketCount <= cast(size_t) a)
			bucketCount <<= 1;
		Node[][] mutableBuckets = cast(Node[][]) Mallocator.it.allocate((Node[]).sizeof * bucketCount);
		Node[] mutableNodes = cast(Node[]) Mallocator.it.allocate(Node.sizeof * values.length);

		size_t[] lengths = cast(size_t[]) Mallocator.it.allocate(size_t.sizeof * bucketCount);
		lengths[] = 0;
		scope(exit) Mallocator.it.deallocate(lengths);

		size_t[] indexes = cast(size_t[]) Mallocator.it.allocate(size_t.sizeof * values.length);
		scope(exit) Mallocator.it.deallocate(indexes);

		size_t[] hashes = cast(size_t[]) Mallocator.it.allocate(size_t.sizeof * values.length);
		scope(exit) Mallocator.it.deallocate(hashes);

		foreach (i, ref value; values)
		{
			hashes[i] = hashFunction(value);
			indexes[i] = hashes[i] & (mutableBuckets.length - 1);
			lengths[indexes[i]]++;
		}

		size_t j = 0;
		foreach (i, l; lengths)
		{
			mutableBuckets[i] = mutableNodes[j .. j + l];
			j += l;
		}

		lengths[] = 0;
		foreach (i; 0 .. values.length)
		{
			immutable l = lengths[indexes[i]];
			static if (hasMember!(Node, "hash"))
				mutableBuckets[indexes[i]][l].hash = hashes[i];
			mutableBuckets[indexes[i]][l].value = values[i];
			lengths[indexes[i]]++;
		}
		buckets = cast(immutable) mutableBuckets;
		nodes = cast(immutable) mutableNodes;
	}

	~this()
	{
		Mallocator.it.deallocate(cast(void[]) buckets);
		Mallocator.it.deallocate(cast(void[]) nodes);
	}

	/**
	 * Returns: A GC-allocated array containing the contents of this set.
	 */
	immutable(T)[] opSlice() immutable
	{
		if (empty)
			return [];
		T[] values = new T[](nodes.length);
		foreach (i, ref v; values)
		{
			v = nodes[i].value;
		}
		return values;
	}

	/**
	 * Returns: true if this set contains the given value.
	 */
	bool contains(T value) immutable
	{
		if (empty)
			return false;
		size_t hash = hashFunction(value);
		size_t index = hash & (buckets.length - 1);
		if (buckets[index].length == 0)
			return false;
		foreach (ref node; buckets[index])
		{
			static if (hasMember!(Node, "hash"))
				if (hash != node.hash)
					continue;
			if (node.value != value)
				continue;
			return true;
		}
		return false;
	}

	/**
	 * The number of items in the set.
	 */
	size_t length;

	/**
	 * True if the set is empty.
	 */
	bool empty;

private:

	import std.allocator;
	import std.traits;

	static struct Node
	{
		T value;
		static if (!isBasicType!T)
			size_t hash;
	}

	Node[][] buckets;
	Node[] nodes;
}

///
unittest
{
	auto ihs1 = immutable ImmutableHashSet!(int, a => a)([1, 3, 5, 19, 31, 40, 17]);
	assert (ihs1.contains(1));
	assert (ihs1.contains(3));
	assert (ihs1.contains(5));
	assert (ihs1.contains(19));
	assert (ihs1.contains(31));
	assert (ihs1.contains(40));
	assert (ihs1.contains(17));
	assert (!ihs1.contains(100));
	assert (ihs1[].length == 7);

	auto ihs2 = immutable ImmutableHashSet!(int, a => a)([]);
	assert (ihs2.length == 0);
	assert (ihs2.empty);
	assert (ihs2[].length == 0);
	assert (!ihs2.contains(42));
}