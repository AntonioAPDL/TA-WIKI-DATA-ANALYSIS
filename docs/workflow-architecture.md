# Workflow architecture and trust boundaries

```text
Tracked publication repository                       Approved restricted storage
-------------------------------                       ---------------------------
code, metadata, tests, safe docs     ----->          frozen source export
lockfile and controlled policies                     source-freeze evidence
                                                     row-level derivatives
                                                     internal tables and logs
                                                     open-text coding workspace

                                                     source intake
                                                     -> validation manifest (01)
                                                     -> transformation manifest (02)
                                                     -> analysis manifest (03)
                                                               |
                                  qualitative template <------+
                                                               |
                      internal scientific review <-------+
                                      |
                           restricted release candidate
                                      |
                      manual byte-bound attestation
                                      |
                      separate authorized delivery only
                                      |
                                      v
                       approved safe artifact, if any
                       (never copied to Git automatically)
```

## Trust boundaries

1. The repository is a code/documentation boundary, not a restricted-data
   workspace. It may contain controlled metadata, synthetic fixtures, and only
   approved disclosure-safe artifacts.
2. The external restricted root contains source material, row-level derivatives,
   internal tables, open text, and governance evidence. Its location and access
   details are not tracked.
3. The three-stage manifests bind source provenance, metadata, environment,
   code, and output hashes. A downstream stage rejects an altered predecessor.
4. The qualitative branch is manual and restricted. It creates templates and
   hash-only coding snapshots; the automated quantitative pipeline does not
   inspect open text.
5. The release branch first completes internal scientific review, then creates
   a restricted candidate for manual disclosure review. A later attestation
   binds exact candidate bytes, but external delivery remains a separate manual
   decision.

## Reproducibility layers

| Layer | Who can rerun it | Required input |
|---|---|---|
| Code | Authorized coauthor | clean repository, lockfile, synthetic fixtures |
| Restricted analysis | Authorized data analyst | code layer plus frozen source and restricted run evidence |
| Release verification | Authorized reviewer | code layer plus candidate, policy, and restricted attestation |

## Invalidation rules

Create a new analytical lineage when any of the following changes:

- frozen source bytes or source revision;
- live header manifest, item specification, category codebook, checkbox list,
  or transformation rule;
- a listed analytical control or locked environment;
- analysis specification, routing evidence, or cohort rule;
- release policy or candidate universe.

An editorial-only manuscript or layout change does not require an analytical
rerun by itself. It requires a separately recorded authorized build and
downstream review; it never authorizes a later checkout to handle restricted
artifacts.

No result is releasable solely because it is reproducible. Disclosure review and
the separately authorized delivery process remain mandatory.
