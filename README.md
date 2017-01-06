# [har-dulcify](https://github.com/joelpurra/har-dulcify/)

Extract data from [HTTP Archive (HAR) files](http://www.softwareishard.com/blog/har-12-spec/), quite possibly downloaded by [har-heedless](https://github.com/joelpurra/har-heedless/), for some aggregate analysis. You might want to use [har-portent](https://github.com/joelpurra/har-portent/), which runs both downloads multiple dataset variations using har-heedless and then analyzes them with har-dulcify in a single step.



## Usage

```bash
# TODO: describe relevant scripts.
# Start with src/one-shot/*.sh

$ tree src/
# src/
# ├── aggregate
# │   ├── all.sh
# │   ├── analysis.sh
# │   ├── merge.sh
# │   ├── prepare.sh
# │   └── prepare2.sh
# ├── classification
# │   ├── basic.sh
# │   ├── disconnect
# │   │   ├── add.sh
# │   │   ├── analysis.sh
# │   │   └── prepare-service-list.sh
# │   └── public-suffix
# │       ├── add.sh
# │       └── prepare-list.sh
# ├── domains
# │   └── latest
# │       ├── all.sh
# │       └── single.sh
# ├── extract
# │   ├── errors
# │   │   ├── all.sh
# │   │   ├── failed-page-loads.sh
# │   │   ├── page.sh
# │   │   └── successful-page-loads.sh
# │   └── request
# │       ├── expand-parts.sh
# │       └── parts.sh
# ├── multiset
# │   ├── download-retries.sh
# │   ├── non-failed.classification.disconnect.coverage.sh
# │   ├── non-failed.classification.domain-scope.coverage.sh
# │   ├── non-failed.classification.secure.coverage.sh
# │   ├── non-failed.disconnect.categories.coverage.external.sh
# │   ├── non-failed.disconnect.counts.sh
# │   ├── non-failed.disconnect.domains.coverage.external.google.sh
# │   ├── non-failed.disconnect.domains.coverage.external.sh
# │   ├── non-failed.disconnect.organizations.coverage.external.sh
# │   ├── non-failed.mime-types.groups.coverage.external.sh
# │   ├── non-failed.mime-types.groups.coverage.internal.sh
# │   ├── non-failed.mime-types.groups.coverage.origin.sh
# │   ├── non-failed.public-suffix.coverage.external.sh
# │   ├── non-failed.requests.counts.sh
# │   ├── origin-redirects.sh
# │   ├── ratio-buckets.sh
# │   └── request-status.codes.coverage.origin.sh
# ├── one-shot
# │   ├── aggregate.sh
# │   ├── all.sh
# │   ├── data.sh
# │   ├── multiset.sh
# │   ├── preparations.sh
# │   └── questions.sh
# ├── questions
# │   ├── disconnect.categories.organizations.sh
# │   ├── google-gtm-ga-dc.aggregate.sh
# │   ├── google-gtm-ga-dc.sh
# │   ├── origin-redirects.aggregate.sh
# │   ├── origin-redirects.sh
# │   ├── ratio-buckets.aggregate.analysis.sh
# │   ├── ratio-buckets.aggregate.sh
# │   └── ratio-buckets.sh
# └── util
#     ├── array-of-objects-to-csv.sh
#     ├── array-of-objects-to-tsv.sh
#     ├── cat-path.sh
#     ├── clean-csv-sorted-header.sh
#     ├── clean-tsv-sorted-header.sh
#     ├── concat.sh
#     ├── dataset-foreach.sh
#     ├── dataset-query.sh
#     ├── malformed-har.sh
#     ├── parallel-chunks.sh
#     ├── parallel-n-2.sh
#     ├── prepare-alexa-domain-lists.sh
#     ├── prepare-domain-lists.sh
#     ├── prepare-zone-file-domain-lists.sh
#     ├── reduce-merge-deep-add.sh
#     ├── structure.sh
#     ├── take.sh
#     ├── to-array.sh
#     └── unwrap-array.sh
#
# 13 directories, 69 files
```



## Citations

If you use, like, reference, or base work on the thesis report [*Swedes Online: You Are More Tracked Than You Think*](https://joelpurra.com/projects/masters-thesis/#thesis), the IEEE LCN 2016 paper [*Third-party Tracking on the Web: A Swedish Perspective*](https://joelpurra.com/projects/masters-thesis/#ieee-lcn-2016), open [source code](https://joelpurra.com/projects/masters-thesis/#open-source), or [open data](https://joelpurra.com/projects/masters-thesis/#open-data), please add at least on of the following two citations with a link to the project website: https://joelpurra.com/projects/masters-thesis/

[Master's thesis](https://joelpurra.com/projects/masters-thesis/#thesis) citation:

> Joel Purra. 2015. Swedes Online: You Are More Tracked Than You Think. Master's thesis. Linköping University (LiU), Linköping, Sweden. https://joelpurra.com/projects/masters-thesis/


[IEEE LCN 2016 paper](https://joelpurra.com/projects/masters-thesis/#ieee-lcn-2016) citation:

> J. Purra, N. Carlsson, Third-party Tracking on the Web: A Swedish Perspective, Proc. IEEE Conference on Local Computer Networks (LCN), Dubai, UAE, Nov. 2016. https://joelpurra.com/projects/masters-thesis/



## Original purpose

Built as a component in [Joel Purra's master's thesis](http://joelpurra.com/projects/masters-thesis/) research, where downloading lots of front pages in the .se top level domain zone was required to analyze their content and use of internal/external resources.


---

Copyright (c) 2014, 2015, 2016, 2017 [Joel Purra](http://joelpurra.com/). Released under [GNU General Public License version 3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl.html).
