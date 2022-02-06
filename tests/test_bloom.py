import os
from random import shuffle

import pytest
from starkware.starknet.testing.starknet import Starknet


CONTRACT_FILE = os.path.join("contracts", "bloom.cairo")


@pytest.mark.asyncio
async def test_bloom_filter():
    starknet = await Starknet.empty()
    contract = await starknet.deploy(source=CONTRACT_FILE)

    # Add 0-24 to the filter
    items_present, items_absent = list(range(25)), list(range(25, 35))
    for item in items_present:
        await contract.bloom_add(item=item).invoke()
    
    # Assert anything 0-24 exists and 25-34 does not exist
    test_items = items_present + items_absent
    shuffle(test_items)
    for item in items_absent:
        execution_info = await contract.bloom_check(item=item).call()
        (exists,) = execution_info.result
        if exists == 1:
            assert item in items_present, "False positive"
        else:
            assert item in items_absent, "False negative"
