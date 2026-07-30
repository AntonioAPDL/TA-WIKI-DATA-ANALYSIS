# Private-repository handoff

The designated clean-history publication repository is
`ta-wiki-assessment-publication`. The earlier development repository has unsafe
history and must never be cloned, copied with `.git`, pushed, or used as a
remote source.

The workflow does not create or administer a remote. A technical private remote
has been provisioned and verified by the repository maintainer, but that fact
does not establish an approved governed destination for restricted records or a
final delivery authorization. Use a fresh clone at each transfer and
verification boundary; do not publish from an accumulated development
workspace.

## Last recorded technical verification

As of 2026-07-26, the remote's `main` baseline at commit
`fce1fdba733e6837d65307ca8bb34c7197ea772e` completed GitHub Actions run
`30212187441` successfully. That run restored the locked environment, enforced
the strict-history privacy boundary, ran privacy and private-handoff verifier
tests, ran the synthetic and manifest-lineage suite, and checked that the
working tree remained clean. An independent fresh clone of the remote was also
clean and rebuilt the results-free coauthor review brief and nonnumeric article
preview.

This is historic technical repository evidence only. It does not verify visibility,
least-privilege membership, named reviewer roles, retention controls,
institutional approval, restricted-data processing, disclosure review, or final
delivery. Those remain explicit human-record requirements below.

1. Before final handoff, record and confirm the destination's visibility,
   ownership, least-privilege access, reviewer roles, branch-protection
   settings, and retention/archive expectations in the hosting and governance
   records. Technical remote existence is not this confirmation.
2. Select the reviewed commit and create a **fresh source clone** containing
   only that reachable reviewed history. Do not copy an accumulated workspace or
   its `.git` directory. Run the synthetic suite and privacy checks in this
   source clone before publishing a branch. The recorded technical check at
   `fce1fdba733e6837d65307ca8bb34c7197ea772e` must be repeated if the final
   source changes.
3. In that fresh source clone, add the verified private remote as `origin`, push
   a review branch, and open a draft pull request. Do not bypass review or
   branch rules.
4. Create a second **fresh clone from the private remote** for final validation.
   The 2026-07-26 technical verification completed this check for a prior
   baseline; repeat it for the final reviewed source. In this remote clone,
   enable hooks and run the synthetic suite plus:

   ```powershell
   git config core.hooksPath .githooks
   $python = 'C:\path\to\python.exe' # a real Python 3 executable, not a Windows Store alias
   & $python scripts/verify_private_handoff.py . --strict-history `
     --require-hooks --require-origin --require-origin-only
   ```

5. The verifier confirms only repository-side conditions: a clean worktree, no
   unreachable objects, the strict privacy scan, installed hooks, and a
   credential-free `origin`. It cannot verify remote visibility, access roles,
   branch protection, or institutional approval. Preserve the resulting handoff
   record outside Git if it names local paths. If a workspace fails because it
   contains unreachable objects, do not publish from it or treat local history
   cleanup as release proof; validate a newly cloned reviewed remote instead.
6. Confirm the remote contains only reviewed code, controlled metadata,
   synthetic tests, safe documentation, and explicitly approved safe artifacts.
7. Record the remote URL, verified visibility, commit, tag, and reviewers in
   the appropriate restricted/project governance record, not this repository.
