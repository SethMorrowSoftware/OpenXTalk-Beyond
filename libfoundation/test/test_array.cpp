/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

// OXT-Beyond: an array's kind mark (MCArrayKindMark), LiveCode 11's
// sequence and dictionary. The mark is part of the array's flags: it
// survives copies, mutable copies and the indirect arrays they make, and
// equality and hashing ignore it.

#include "gtest/gtest.h"

#include "foundation.h"
#include "foundation-auto.h"

static MCArrayRef MakeSequence(uindex_t p_count)
{
    MCArrayRef t_array;
    if (!MCArrayCreateMutable(t_array))
        return nil;
    for (uindex_t i = 1; i <= p_count; i++)
    {
        MCAutoNumberRef t_number;
        if (!MCNumberCreateWithInteger(i * 10, &t_number) ||
            !MCArrayStoreValueAtIndex(t_array, i, *t_number))
        {
            MCValueRelease(t_array);
            return nil;
        }
    }
    return t_array;
}

TEST(array, kindmark_none_by_default)
{
    MCAutoArrayRef t_array;
    t_array.Give(MakeSequence(2));
    ASSERT_TRUE(*t_array != nil);
    EXPECT_EQ(MCArrayGetKindMark(*t_array), kMCArrayKindMarkNone);
    EXPECT_EQ(MCArrayGetKindMark(kMCEmptyArray), kMCArrayKindMarkNone);
}

TEST(array, kindmark_set_and_clear)
{
    MCAutoArrayRef t_array;
    t_array.Give(MakeSequence(2));
    ASSERT_TRUE(MCArraySetKindMark(*t_array, kMCArrayKindMarkSequence));
    EXPECT_EQ(MCArrayGetKindMark(*t_array), kMCArrayKindMarkSequence);
    ASSERT_TRUE(MCArraySetKindMark(*t_array, kMCArrayKindMarkDictionary));
    EXPECT_EQ(MCArrayGetKindMark(*t_array), kMCArrayKindMarkDictionary);
    ASSERT_TRUE(MCArraySetKindMark(*t_array, kMCArrayKindMarkNone));
    EXPECT_EQ(MCArrayGetKindMark(*t_array), kMCArrayKindMarkNone);
    // The elements are untouched
    EXPECT_EQ(MCArrayGetCount(*t_array), 2u);
}

TEST(array, kindmark_survives_copy)
{
    MCAutoArrayRef t_array;
    t_array.Give(MakeSequence(3));
    ASSERT_TRUE(MCArraySetKindMark(*t_array, kMCArrayKindMarkSequence));

    MCAutoArrayRef t_copy;
    ASSERT_TRUE(MCArrayCopy(*t_array, &t_copy));
    EXPECT_FALSE(MCArrayIsMutable(*t_copy));
    EXPECT_EQ(MCArrayGetKindMark(*t_copy), kMCArrayKindMarkSequence);

    // The mutable array is now indirect: storing into it copies its
    // contents, and the mark goes with them
    MCAutoNumberRef t_number;
    ASSERT_TRUE(MCNumberCreateWithInteger(40, &t_number));
    ASSERT_TRUE(MCArrayStoreValueAtIndex(*t_array, 4, *t_number));
    EXPECT_EQ(MCArrayGetKindMark(*t_array), kMCArrayKindMarkSequence);
    EXPECT_EQ(MCArrayGetCount(*t_array), 4u);
    EXPECT_EQ(MCArrayGetCount(*t_copy), 3u);
    EXPECT_EQ(MCArrayGetKindMark(*t_copy), kMCArrayKindMarkSequence);
}

TEST(array, kindmark_survives_mutable_copy)
{
    MCAutoArrayRef t_array;
    t_array.Give(MakeSequence(2));
    ASSERT_TRUE(MCArraySetKindMark(*t_array, kMCArrayKindMarkDictionary));
    MCAutoArrayRef t_immutable;
    ASSERT_TRUE(MCArrayCopy(*t_array, &t_immutable));

    MCAutoArrayRef t_mutable;
    ASSERT_TRUE(MCArrayMutableCopy(*t_immutable, &t_mutable));
    EXPECT_EQ(MCArrayGetKindMark(*t_mutable), kMCArrayKindMarkDictionary);

    // Changing the mark of the mutable copy leaves the original alone
    ASSERT_TRUE(MCArraySetKindMark(*t_mutable, kMCArrayKindMarkSequence));
    EXPECT_EQ(MCArrayGetKindMark(*t_mutable), kMCArrayKindMarkSequence);
    EXPECT_EQ(MCArrayGetKindMark(*t_immutable), kMCArrayKindMarkDictionary);
    EXPECT_EQ(MCArrayGetCount(*t_mutable), 2u);
}

TEST(array, kindmark_copy_with_kind_mark)
{
    MCAutoArrayRef t_array;
    t_array.Give(MakeSequence(2));
    MCAutoArrayRef t_immutable;
    ASSERT_TRUE(MCArrayCopy(*t_array, &t_immutable));

    MCAutoArrayRef t_sequence;
    ASSERT_TRUE(MCArrayCopyWithKindMark(*t_immutable, kMCArrayKindMarkSequence, &t_sequence));
    EXPECT_FALSE(MCArrayIsMutable(*t_sequence));
    EXPECT_EQ(MCArrayGetKindMark(*t_sequence), kMCArrayKindMarkSequence);
    EXPECT_EQ(MCArrayGetKindMark(*t_immutable), kMCArrayKindMarkNone);

    // The same mark again is the same array
    MCAutoArrayRef t_again;
    ASSERT_TRUE(MCArrayCopyWithKindMark(*t_sequence, kMCArrayKindMarkSequence, &t_again));
    EXPECT_EQ(*t_again, *t_sequence);

    // An empty array can carry a mark: it is then not the shared empty array
    MCAutoArrayRef t_empty_dictionary;
    ASSERT_TRUE(MCArrayCopyWithKindMark(kMCEmptyArray, kMCArrayKindMarkDictionary, &t_empty_dictionary));
    EXPECT_EQ(MCArrayGetKindMark(*t_empty_dictionary), kMCArrayKindMarkDictionary);
    EXPECT_EQ(MCArrayGetKindMark(kMCEmptyArray), kMCArrayKindMarkNone);
    EXPECT_TRUE(MCArrayIsEmpty(*t_empty_dictionary));
}

TEST(array, kindmark_ignored_by_equality_and_hash)
{
    MCAutoArrayRef t_plain, t_marked;
    t_plain.Give(MakeSequence(3));
    t_marked.Give(MakeSequence(3));
    ASSERT_TRUE(MCArraySetKindMark(*t_marked, kMCArrayKindMarkDictionary));
    EXPECT_TRUE(MCValueIsEqualTo(*t_plain, *t_marked));
    EXPECT_EQ(MCValueHash(*t_plain), MCValueHash(*t_marked));

    MCAutoArrayRef t_empty_sequence;
    ASSERT_TRUE(MCArrayCopyWithKindMark(kMCEmptyArray, kMCArrayKindMarkSequence, &t_empty_sequence));
    EXPECT_TRUE(MCValueIsEqualTo(*t_empty_sequence, kMCEmptyArray));
}
