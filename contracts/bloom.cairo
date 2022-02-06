%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, split_felt, unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem

from contracts.utils.constants import FALSE, TRUE

# TODO: make these parameters configurable

# Probability of false positives
# p = 0.0001
# Number of items in the filter
const N = 5000
# Number of bits in the filter
const SIZE = 95841
# Number of hash functions to perform
const K = 13

# The actual filter
@storage_var
func bit_array(index : Uint256) -> (res : felt):
end

# Total items added to the filter
@storage_var
func total_items() -> (res : felt):
end

# Recursively flip bits for all indices [H(item, i) for i in range(K)]
func _add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        item : felt, hash_count : felt):
    alloc_locals
    if hash_count == 0:
        return ()
    end

    let (h1) = hash2{hash_ptr=pedersen_ptr}(item, hash_count)
    let (h1_high, h1_low) = split_felt(h1)
    let h1_uint256 = Uint256(low=h1_low, high=h1_high)

    let (size_high, size_low) = split_felt(SIZE)
    let size_uint256 = Uint256(low=size_low, high=size_high)

    # digest = H( item , seed ) % SIZE
    let (_, digest) = uint256_unsigned_div_rem(h1_uint256, size_uint256)

    # TODO: replace with actual packing, using a full felt for a single bit feels gross
    # Examples for later:
    # * https://gist.github.com/Pet3ris/5d0f3c094a9ec99aff54025a790aa0a7
    # * https://github.com/perama-v/GoL2/blob/main/contracts/utils/packing.cairo#L40
    # * https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/bitwise.cairo
    bit_array.write(index=digest, value=TRUE)
    _add(item, hash_count - 1)
    return ()
end

# Add an item to the bloom filter, reverting if no remaining space
@external
func bloom_add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(item : felt):
    alloc_locals

    let (local current_total) = total_items.read()
    assert_le(current_total + 1, N)
    total_items.write(current_total + 1)

    _add(item, K)
    return ()
end

# Recursively check that bits are flipped at all indices [H(item, i) for i in range(K)]
func _check{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        item : felt, hash_count : felt) -> (res : felt):
    alloc_locals

    if hash_count == 0:
        return (res=TRUE)  # Item probably exists
    end

    # Seed with the unique hash iteration being performed
    let (h1) = hash2{hash_ptr=pedersen_ptr}(item, hash_count)
    let (h1_high, h1_low) = split_felt(h1)
    let h1_uint256 = Uint256(low=h1_low, high=h1_high)
    let (size_high, size_low) = split_felt(SIZE)
    let size_uint256 = Uint256(low=size_low, high=size_high)

    # digest = H( item , seed ) % SIZE
    let (_, digest) = uint256_unsigned_div_rem(h1_uint256, size_uint256)
    let (local is_flipped) = bit_array.read(index=digest)
    if is_flipped == FALSE:
        return (FALSE)  # Item definitely does not exist
    end

    let (res) = _check(item, hash_count - 1)
    return (res)
end

# Check for the existence of an item in the bloom filter
@view
func bloom_check{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        item : felt) -> (exists : felt):
    let (exists) = _check(item, K)
    return (exists)
end
