# [checksum](https://corz.org/windows/software/checksum/)

checksum creates and verifies file hashes on 64-bit Windows. Right-click a file, folder, or drive in Windows Explorer to hash it or check it against saved hashes. Use it to verify downloads, check backups for corruption, or confirm that a batch of files transferred intact.

- Hash individual files or scan a whole directory tree recursively.
- Use SHA-256 (the default), SHA-1, MD5, or CRC32. A single `.hash` file can contain entries from several algorithms.
- Save hashes in one file for an entire tree, one per folder, or one per file.
- Work with long Windows paths and Unicode filenames. Filter which files to hash using filename masks.
- Hold **Shift** while choosing a checksum command in Explorer to change the options for that run. Use command-line switches for scripts and scheduled tasks.

## Download and run

Get the Windows download from the [official checksum page](https://corz.org/windows/software/checksum/). Install it for Explorer integration, or run it in portable mode by placing `checksum.ini` beside `checksum.exe`.

## Source

The AutoIt entry point is [checksum.au3](checksum.au3). Supporting code is in [Includes](Includes/) and application assets are in [Resources](Resources/).
