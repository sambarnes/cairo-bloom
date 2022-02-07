# 🥀 cairo-bloom

A naive [bloom filter](https://en.wikipedia.org/wiki/Bloom_filter) implementation in [Cairo](https://www.cairo-lang.org/docs/).

> A Bloom filter is a space-efficient probabilistic data structure, conceived by Burton Howard Bloom in 1970, that is used to test whether an element is a member of a set. False positive matches are possible, but false negatives are not – in other words, a query returns either "possibly in set" or "definitely not in set". Elements can be added to the set, but not removed (though this can be addressed with the counting Bloom filter variant); the more items added, the larger the probability of false positives.

Motivation from [this blogpost](https://hackmd.io/@RoboTeddy/BJZFu56wF#Maxim-Computation-is-cheap-Writes-are-expensive) that states a maxim for StarkNet: `Computation is cheap. Writes are expensive.` That said, a bloom filter seems like it will be a fairly common tool to reach for when wanting to check membership of a set, without having to store that full set on chain.

**Better implementations likely exist :)**

~~I used a full felt of storage for every bit in the bitarray. Probably should try to actually use the rest of the bits in each felt.~~ Optimized a little bit, now stores 64 bits per felt of storage. 

## Development

Start a new virtual environment:
```
sam@sam:~/dev/eth/starknet/cairo-bloom$ python3.7 -m venv venv
sam@sam:~/dev/eth/starknet/cairo-bloom$ source venv/bin/activate
```

Install [OpenZeppelin's nile](https://github.com/OpenZeppelin/nile), then use it to install the StarkNet toolchain:
```
(venv) sam@sam:~/dev/eth/starknet/cairo-bloom$ python -m pip install cairo-nile
(venv) sam@sam:~/dev/eth/starknet/cairo-bloom$ nile install
```

Run unit tests:
```
(venv) sam@sam:~/dev/eth/starknet/cairo-bloom$ make test
pytest tests/
==================== test session starts =====================
platform linux -- Python 3.7.12, pytest-7.0.0, pluggy-1.0.0
rootdir: /home/sam/dev/eth/starknet/cairo-bloom
plugins: typeguard-2.13.3, asyncio-0.17.2, web3-5.27.0
asyncio: mode=legacy
collected 1 item                                             

tests/test_bloom.py .                                  [100%]

=============== 1 passed, 2 warnings in 51.79s ===============
```
