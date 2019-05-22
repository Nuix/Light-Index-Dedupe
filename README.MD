Light Index Dedupe
==================

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) ![This script was last tested in Nuix 7.8](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-7.8-green.svg)

View the GitHub project [here](https://github.com/Nuix/Light-Index-Dedupe) or download the latest release [here](https://github.com/Nuix/Light-Index-Dedupe/releases).

# Overview

**Written By:** Jason Wells

Creates item sets in instances where a "light index" ingestion was performed and items in a case may not have MD5, SHA1 or SHA256 hashes to deduplicate with.  The script accomplishes this by using a concatenation of data which is available (such as file size and last modified date).  An MD5 is generated from the concatenated values, which is then used for deduplication while adding items to the item set.  This has the downside that deduplication is not necessarily as accurate, but can provide a "big picture" rough idea of how duplicative data on a file system may be.

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Usage

Begin by selecting some items, then run the script.  A settings dialog will be displayed with the following settings:

| Setting | Description |
|---------|-------------|
| **Item Set Name** | Name of the item set to add the custom deduplicated items to.  If an item set with the given name exists, the items will be added to it.  If an item set with the given name does not already exist, one will be created. |
| **Batch Name** | Name of the item set batch to add custom deduplicated items to. |
| **Use Name** | Whether item name should be included in the concatenated string from which the deduplication MD5 will be derived. |
| **Use 'File Size'** | Whether item file size should be included in the concatenated string from which the deduplication MD5 will be derived. |
| **Use 'File Modified'** | Whether item file modified time should be included in the concatenated string from which the deduplication MD5 will be dervied. |
| **Accuracy to Millisecond** | Determines the format string used to convert 'File Modified' to a string.  This choice includes the time down to the fraction of a second.  For this choice the format string used is:<br> `yyyy/MM/dd HH:mm:ss.SSS`. |
| **Accuracy to Second** | Determines the format string used to convert 'File Modified' to a string.  This choice includes the time down to the whole second.  Can be useful if you expect different instances of the same data to have slightly differing sub-second 'File Modified' values.  For this choice the format string used is:<br> `yyyy/MM/dd HH:mm:ss`. |
| **Accuracy to Minute** | Determines the format string used to convert 'File Modified' to a string.  This choice includes the time down to the whole minute.  Can be useful if you expect different instances of the same data to have slightly differing values in seconds.  Likely not that useful, but added in case there is value in this for someone.  For this choice the format string used is:<br> `yyyy/MM/dd HH:mm`. |
| **Use Content Text** | Whether to include item content text in the concatenated string from which the deduplication MD5 will be derived. The script uses a copy of the item content text with all whitespace removed when this option is checked, to account for instances where whitespace characters may vary due to differing source formats for otherwise duplicative data.  Whitespace removal is mostly for instances where the same email may have been stored in different formats which may yield slight variations in whitespace for otherwise duplicative emails. |
| **Dedupe by Family** | When checked, deduplication MD5 will be generated for a given item from that item's top level item.  If the item is above top level, and therfore has no top level item, the deduplication MD5 will be generated from the item itself.  If this is not checked, deduplication Md5 will be generated from each given input item rather than its corresponding top level item. |
| **Pull in Family Members of Selected Items** | When checked, the script will take the items selected when the script was ran and include all their family members.  When not checked, only the item you had selected when you ran the script will be added to the item set the script creates. |

# Cloning this Repository

This script relies on code from [Nx](https://github.com/Nuix/Nx) to present a settings dialog and progress dialog.  This JAR file is not included in the repository (although it is included in release downloads).  If you clone this repository, you will also want to obtain a copy of Nx.jar by either:
1. Building it from [the source](https://github.com/Nuix/Nx)
2. Downloading an already built JAR file from the [Nx releases](https://github.com/Nuix/Nx/releases)

Once you have a copy of Nx.jar, make sure to include it in the same directory as the script.

# License

```
Copyright 2019 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```