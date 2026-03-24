
# tls

## Code Reorg
un seul sequence split pr toute l'app.
_append_number_buffer: [16]string_type, -> a la string (not thread safe)

## Code Reorg

- [X] compile for zig 0.14? 
- [ ] profile, make it faster.
- [ ] change to utf8
- [ ] check lifecycle of every entity (do i deinit?)
- [ ] do i keep deinit for stack?
- [X] termwriter: only write to output once per line.

## Tests

## Bug

- [ ] hours is not correct.
- [ ] extra attributes not display anymore.
- [X] directory shant print size.
- [ ] if seq too long, only print min / max + !!
- [ ] lots of copy, where to use pointers?

## Missing Features.

- [X] ls non current dir.
- [X] display multiple seq.
- [ ] sequence of directories.
- [ ] symlinks
- [ ] display extra files.
- [ ] color for images / archives / dcc files.
- [.] alignement of colomns.
    - [X] aligns users.
    - [ ] align to minimum size to win spaces...
    - [ ] for extra: do I align? if multiple seq yes, but only aligns with size of those.
