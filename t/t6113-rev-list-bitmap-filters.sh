#!/bin/sh

test_description='rev-list combining bitmaps and filters'
. ./test-lib.sh

test_expect_success 'set up bitmapped repo' '
	# one commit will have bitmaps, the other will not
	test_commit one &&
	test_commit much-larger-blob-one &&
	git repack -adb &&
	test_commit two &&
	test_commit much-larger-blob-two
'

test_expect_success 'filters fallback to non-bitmap traversal' '
	# use a path-based filter, since they are inherently incompatible with
	# bitmaps (i.e., this test will never get confused by later code to
	# combine the features)
	filter=$(echo "!one" | git hash-object -w --stdin) &&
	git rev-list --objects --filter=sparse:oid=$filter HEAD >expect &&
	git rev-list --use-bitmap-index \
		     --objects --filter=sparse:oid=$filter HEAD >actual &&
	test_cmp expect actual
'

# the bitmap and regular traversals produce subtly different output:
#
#   - regular output is in traversal order, whereas bitmap is split by type,
#     with non-packed objects at the end
#
#   - regular output has a space and the pathname appended to non-commit
#     objects; bitmap output omits this
#
# Normalize and compare the two. The second argument should always be the
# bitmap output.
cmp_bitmap_traversal () {
	if cmp "$1" "$2"
	then
		echo >&2 "identical raw outputs; are you sure bitmaps were used?"
		return 1
	fi &&
	cut -d' ' -f1 "$1" | sort >"$1.normalized" &&
	sort "$2" >"$2.normalized" &&
	test_cmp "$1.normalized" "$2.normalized"
}

test_expect_success 'blob:none filter' '
	git rev-list --objects --filter=blob:none HEAD >expect &&
	git rev-list --use-bitmap-index \
		     --objects --filter=blob:none HEAD >actual &&
	cmp_bitmap_traversal expect actual
'

test_expect_success 'blob:none filter with specified blob' '
	git rev-list --objects --filter=blob:none HEAD HEAD:two.t >expect &&
	git rev-list --use-bitmap-index \
		     --objects --filter=blob:none HEAD HEAD:two.t >actual &&
	cmp_bitmap_traversal expect actual
'

test_expect_success 'blob:limit filter' '
	git rev-list --objects --filter=blob:limit=5 HEAD >expect &&
	git rev-list --use-bitmap-index \
		     --objects --filter=blob:limit=5 HEAD >actual &&
	cmp_bitmap_traversal expect actual
'

test_expect_success 'blob:limit filter with specified blob' '
	git rev-list --objects --filter=blob:limit=5 \
		     HEAD HEAD:much-larger-blob-two.t >expect &&
	git rev-list --use-bitmap-index \
		     --objects --filter=blob:limit=5 \
		     HEAD HEAD:much-larger-blob-two.t >actual &&
	cmp_bitmap_traversal expect actual
'

test_done
