%lang starknet

from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, split_felt, unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem

from contracts.lib.bitwise import bitshift_left
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

# TODO: Figure out a way to use more of a single felt?
# Can only store 64 bits in each storage segment due to a constratint in:
# contracts.lib.bitwise.bitshift_left
const BITS_PER_ARRAY = 64

# The actual filter, comprised of multiple smaller bit arrays.
# {
#   0: [0, 1, 2, ..., 63],
#   1: [0, 1, 2, ..., 63],
#   ...
# }
@storage_var
func bit_arrays(index : Uint256) -> (res : felt):
end

# Total items added to the filter
@storage_var
func total_items() -> (res : felt):
end

# Recursively flip bits for all indices [H(item, i) for i in range(K)]
func _add{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr}(item : felt, hash_count : felt):
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

    # Find the right bit array
    let (bit_array_size_high, bit_array_size_low) = split_felt(BITS_PER_ARRAY)
    let bit_array_size_uint256 = Uint256(low=bit_array_size_low, high=bit_array_size_high)
    let (bit_array_index, sub_index) = uint256_unsigned_div_rem(digest, bit_array_size_uint256)
    let (existing_bit_array) = bit_arrays.read(index=bit_array_index)

    # Set the one bit at sub_index
    let (new_bit) = bitshift_left(1, sub_index.low)
    let (updated_bit_array) = bitwise_and(existing_bit_array, new_bit)
    bit_arrays.write(index=bit_array_index, value=updated_bit_array)

    _add(item, hash_count - 1)
    return ()
end

# Add an item to the bloom filter, reverting if no remaining space
@external
func bloom_add{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr}(item : felt):
    alloc_locals

    let (local current_total) = total_items.read()
    assert_le(current_total + 1, N)
    total_items.write(current_total + 1)

    _add(item, K)
    return ()
end

# Recursively check that bits are flipped at all indices [H(item, i) for i in range(K)]
func _check{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr}(item : felt, hash_count : felt) -> (res : felt):
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

    # Find the right bit array
    let (bit_array_size_high, bit_array_size_low) = split_felt(BITS_PER_ARRAY)
    let bit_array_size_uint256 = Uint256(low=bit_array_size_low, high=bit_array_size_high)
    let (bit_array_index, sub_index) = uint256_unsigned_div_rem(digest, bit_array_size_uint256)
    let (existing_bit_array) = bit_arrays.read(index=bit_array_index)

    # Mask for only the one bit at sub_index
    let (expected_bit) = bitshift_left(1, sub_index.low)
    let (observed_bit) = bitwise_and(existing_bit_array, expected_bit)
    if observed_bit != expected_bit:
        return (FALSE)  # Item definitely does not exist
    end

    let (res) = _check(item, hash_count - 1)
    return (res)
end

# Check for the existence of an item in the bloom filter
@view
func bloom_check{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr}(item : felt) -> (exists : felt):
    let (exists) = _check(item, K)
    return (exists)
end
