module vlmdb

#flag -I @VMODROOT/thirdparty/
#flag @VMODROOT/thirdparty/mdb.o
#flag @VMODROOT/thirdparty/midl.o

#include "lmdb.h"

//*@file lmdb.h
//  Lightning memory-mapped database library
// * *@mainpage	Lightning Memory-Mapped Database Manager (LMDB)
// * *@section intro_sec Introduction
// *LMDB is a Btree-based database management library modeled loosely on the
// *BerkeleyDB API, but much simplified. The entire database is exposed
// *in a memory map, and all data fetches return data directly
// *from the mapped memory, so no malloc's or memcpy's occur during
// *data fetches. As such, the library is extremely simple because it
// *requires no page caching layer of its own, and it is extremely high
// *performance and memory-efficient. It is also fully transactional with
// *full ACID semantics, and when the memory map is read-only, the
// *database integrity cannot be corrupted by stray pointer writes from
// *application code.
// * *The library is fully thread-aware and supports concurrent read/write
// *access from multiple processes and threads. Data pages use a copy-on-
// *write strategy so no active data pages are ever overwritten, which
// *also provides resistance to corruption and eliminates the need of any
// *special recovery procedures after a system crash. Writes are fully
// *serialized; only one write transaction may be active at a time, which
// *guarantees that writers can never deadlock. The database structure is
// *multi-versioned so readers run with no locks; writers cannot block
// *readers, and readers don't block writers.
// * *Unlike other well-known database mechanisms which use either write-ahead
// *transaction logs or append-only data writes, LMDB requires no maintenance
// *during operation. Both write-ahead loggers and append-only databases
// *require periodic checkpointing and/or compaction of their log or database
// *files otherwise they grow without bound. LMDB tracks free pages within
// *the database and re-uses them for new write operations, so the database
// *size does not grow without bound in normal use.
// * *The memory map can be used as a read-only or read-write map. It is
// *read-only by default as this provides total immunity to corruption.
// *Using read-write mode offers much higher write performance, but adds
// *the possibility for stray application writes thru pointers to silently
// *corrupt the database. Of course if your application code is known to
// *be bug-free (...) then this is not an issue.
// * *If this is your first time using a transactional embedded key/value
// *store, you may find the \ref starting page to be helpful.
// * *@section caveats_sec Caveats
// *Troubleshooting the lock file, plus semaphores on BSD systems:
// * *- A broken lockfile can cause sync issues.
// *  Stale reader transactions left behind by an aborted program
// *  cause further writes to grow the database quickly, and
// *  stale locks can block further operation.
// * *  Fix: Check for stale readers periodically, using the
// *  #mdb_reader_check function or the \ref mdb_stat_1 "mdb_stat" tool.
// *  Stale writers will be cleared automatically on most systems:
// *  - Windows - automatic
// *  - BSD, systems using SysV semaphores - automatic
// *  - Linux, systems using POSIX mutexes with Robust option - automatic
// *  Otherwise just make all programs using the database close it;
// *  the lockfile is always reset on first open of the environment.
// * *- On BSD systems or others configured with MDB_USE_SYSV_SEM or
// *  MDB_USE_POSIX_SEM,
// *  startup can fail due to semaphores owned by another userid.
// * *  Fix: Open and close the database as the user which owns the
// *  semaphores (likely last user) or as root, while no other
// *  process is using the database.
// * *Restrictions/caveats (in addition to those listed for some functions):
// * *- Only the database owner should normally use the database on
// *  BSD systems or when otherwise configured with MDB_USE_POSIX_SEM.
// *  Multiple users can cause startup to fail later, as noted above.
// * *- There is normally no pure read-only mode, since readers need write
// *  access to locks and lock file. Exceptions: On read-only filesystems
// *  or with the #MDB_NOLOCK flag described under `#mdb_env_open()`.
// * *- An LMDB configuration will often reserve considerable \b unused
// *  memory address space and maybe file size for future growth.
// *  This does not use actual memory or disk space, but users may need
// *  to understand the difference so they won't be scared off.
// * *- By default, in versions before 0.9.10, unused portions of the data
// *  file might receive garbage data from memory freed by other code.
// *  (This does not happen when using the #MDB_WRITEMAP flag.) As of
// *  0.9.10 the default behavior is to initialize such memory before
// *  writing to the data file. Since there may be a slight performance
// *  cost due to this initialization, applications may disable it using
// *  the #MDB_NOMEMINIT flag. Applications handling sensitive data
// *  which must not be written should not use this flag. This flag is
// *  irrelevant when using #MDB_WRITEMAP.
// * *- A thread can only use one transaction at a time, plus any child
// *  transactions.  Each transaction belongs to one thread.  See below.
// *  The #MDB_NOTLS flag changes this for read-only transactions.
// * *- Use an MDB_env*in the process which opened it, not after fork().
// * *- Do not have open an LMDB database twice in the same process at
// *  the same time.  Not even from a plain open() call - close()ing it
// *  breaks fcntl() advisory locking.  (It is OK to reopen it after
// *  fork() - exec*), since the lockfile has FD_CLOEXEC set.)
// * *- Avoid long-lived transactions.  Read transactions prevent
// *  reuse of pages freed by newer write transactions, thus the
// *  database can grow quickly.  Write transactions prevent
// *  other write transactions, since writes are serialized.
// * *- Avoid suspending a process with active transactions.  These
// *  would then be "long-lived" as above.  Also read transactions
// *  suspended when writers commit could sometimes see wrong data.
// * *...when several processes can use a database concurrently:
// * *- Avoid aborting a process with an active transaction.
// *  The transaction becomes "long-lived" as above until a check
// *  for stale readers is performed or the lockfile is reset,
// *  since the process may not remove it from the lockfile.
// * *  This does not apply to write transactions if the system clears
// *  stale writers, see above.
// * *- If you do that anyway, do a periodic check for stale readers. Or
// *  close the environment once in a while, so the lockfile can get reset.
// * *- Do not use LMDB databases on remote filesystems, even between
// *  processes on the same host.  This breaks flock() on some OSes,
// *  possibly memory map sync, and certainly sync between programs
// *  on different hosts.
// * *- Opening a database can fail if another process is opening or
// *  closing it at exactly the same time.
// * *@author	Howard Chu, Symas Corporation.
// * *@copyright Copyright 2011-2021 Howard Chu, Symas Corp. All rights reserved.
// * *Redistribution and use in source and binary forms, with or without
// *modification, are permitted only as authorized by the OpenLDAP
// *Public License.
// * *A copy of this license is available in the file LICENSE in the
// *top-level directory of the distribution or, alternatively, at
// *<http://www.OpenLDAP.org/license.html>.
// * *@par Derived From:
// *This code is derived from btree.c written by Martin Hedenfalk.
// * *Copyright (c) 2009, 2010 Martin Hedenfalk <martin@bzero.se>
// * *Permission to use, copy, modify, and distribute this software for any
// *purpose with or without fee is hereby granted, provided that the above
// *copyright notice and this permission notice appear in all copies.
// * *THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// *WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// *MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// *ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// *WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// *ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// *OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

@[typedef]
struct C.MDB_val {
pub mut:
	//* size of the data item
	mv_size usize
	//* address of the data item
	mv_data voidptr
}

@[typedef]
struct C.MDB_txn {}

@[typedef]
struct C.MDB_env {}

@[typedef]
struct C.MDB_envinfo {}

@[typedef]
struct C.MDB_stat {}

@[typedef]
struct C.MDB_cursor {}

// @[typedef]
// struct C.mdb_mode_t {}

// Opaque structure for navigating through a database
// Generic structure used for passing keys and data in and out
// of the database.
// Values returned from the database are valid only until a subsequent
// update operation, or the end of the transaction. Do not modify or
// free them, they commonly point into the database itself.
// Key sizes must be between 1 and `#mdb_env_get_maxkeysize()` inclusive.
// The same applies to data sizes in databases with the #MDB_DUPSORT flag.
// Other data items can in theory be from 0 to 0xffffffff bytes long.
//
pub type Mdb_val = C.MDB_val

// Opaque structure for a transaction handle.
//
// All database operations require a transaction handle. Transactions may be
// read-only or read-write.
pub type Mdb_txn = C.MDB_txn

//  Opaque structure for a database environment.
// A DB environment supports multiple databases, all residing in the same
// shared-memory map.
//
pub type Mdb_env = C.MDB_env

// Information about the environment
pub type Mdb_envinfo = C.MDB_envinfo

// Statistics for a database in the environment
pub type Mdb_stat = C.MDB_stat

// Opaque structure for navigating through a database
pub type Mdb_cursor = C.MDB_cursor

//*Unix permissions for creating files, or dummy definition for Windows
pub type Mdb_mode_t = u16


//* Unsigned type used for mapsize, entry counts and page/transaction IDs.
//* It is normally size_t, hence the name. Defining MDB_VL32 makes it
//* uint64_t, but do not try this unless you know what you are doing.
//
pub type Mdb_size_t = usize

//* Prevent mixing with non-VL32 builds
//*An abstraction for a file handle.
// *On POSIX systems file handles are small integers. On Windows
// *they're opaque pointers.
//
pub type Mdb_filehandle_t = int

// A handle for an individual database in the DB environment.
pub type Mdb_dbi = u32

// Opaque structure for navigating through a database
// Generic structure used for passing keys and data in and out
// of the database.
// Values returned from the database are valid only until a subsequent
// update operation, or the end of the transaction. Do not modify or
// free them, they commonly point into the database itself.
// Key sizes must be between 1 and `#mdb_env_get_maxkeysize()` inclusive.
// The same applies to data sizes in databases with the #MDB_DUPSORT flag.
// Other data items can in theory be from 0 to 0xffffffff bytes long.
//
// struct MDB_val {
// 	//* size of the data item
// 	mv_size usize
// 	//* address of the data item
// 	mv_data voidptr
// }

// A callback function used to compare two keys in a database
pub type MDB_cmp_func = fn (const_a &Mdb_val, const_b &Mdb_val) int

// A callback function used to relocate a position-dependent data item
// in a fixed-address database.
// * The \b newptr gives the item's desired address in
// the memory map, and \b oldptr gives its previous address. The item's actual
// * data resides at the address in \b item.  This callback is expected to walk
// *through the fields of the record in \b item and modify any
// *values based at the \b oldptr address to be relative to the \b newptr address.
// *@param[in,out] item The item that is to be relocated.
// *@param[in] oldptr The previous address.
// *@param[in] newptr The new address to relocate to.
// *@param[in] relctx An application-provided context, set by `#mdb_set_relctx()`.
// *@todo This feature is currently unimplemented.
//
pub type MDB_rel_func = fn (item &Mdb_val, oldptr voidptr, newptr voidptr, relctx voidptr)

// Cursor Get operations.
//	This is the set of all operations for retrieving data
//	using a cursor.
//
@[flags]
pub enum Mdb_cursor_op {
	//* Position at first key/data item
	mdb_first
	//* Position at first data item of current key.
	// Only for #MDB_DUPSORT
	mdb_first_dup
	//* Position at key/data pair. Only for #MDB_DUPSORT
	mdb_get_both
	//* position at key, nearest data. Only for #MDB_DUPSORT
	mdb_get_both_range
	//* Return key/data at current cursor position
	mdb_get_current
	//* Return up to a page of duplicate data items
	//								from current cursor position. Move cursor to prepare
	//								for #MDB_NEXT_MULTIPLE. Only for #MDB_DUPFIXED
	mdb_get_multiple
	//* Position at last key/data item
	mdb_last
	//* Position at last data item of current key.
	//								Only for #MDB_DUPSORT
	mdb_last_dup
	//* Position at next data item
	mdb_next
	//* Position at next data item of current key.
	//								Only for #MDB_DUPSORT
	mdb_next_dup
	//* Return up to a page of duplicate data items
	//								from next cursor position. Move cursor to prepare
	//								for #MDB_NEXT_MULTIPLE. Only for #MDB_DUPFIXED
	mdb_next_multiple
	//* Position at first data item of next key
	mdb_next_nodup
	//* Position at previous data item
	mdb_prev
	//* Position at previous data item of current key.
	//								Only for #MDB_DUPSORT
	mdb_prev_dup
	//* Position at last data item of previous key
	mdb_prev_nodup
	//* Position at specified key
	mdb_set
	//* Position at specified key, return key + data
	mdb_set_key
	//* Position at first key greater than or equal to specified key.
	mdb_set_range
	// Position at previous page and return up to
	// a page of duplicate data items. Only for #MDB_DUPFIXED
	mdb_prev_multiple
}

//*@defgroup  errors	Return Codes
// * *BerkeleyDB uses -30800 to -30999, we'll go under them
// *@{
//
//*Successful result
//*key/data pair already exists
//*key/data pair not found (EOF)
//*Requested page not found - this usually indicates corruption
//*Located page was wrong type
//*Update of meta page failed or environment had fatal error
//*Environment version mismatch
//*File is not a valid LMDB file
//*Environment mapsize reached
//*Environment maxdbs reached
//*Environment maxreaders reached
//*Too many TLS keys in use - Windows only
//*Txn has too many dirty pages
//*Cursor stack too deep - internal error
//*Page has not enough space - internal error
//*Database contents grew beyond environment mapsize
//*Operation and DB incompatible, or DB type changed. This can mean:
// <ul>
// <li>The operation expects an #MDB_DUPSORT / #MDB_DUPFIXED database.
// <li>Opening a named DB when the unnamed DB has #MDB_DUPSORT / #MDB_INTEGERKEY.
// <li>Accessing a data record as a database, or vice versa.
// <li>The database was dropped and recreated with different flags.
// </ul>
//
//*Invalid reuse of reader locktable slot
//*Transaction must abort, has a child, or is invalid
//*Unsupported size of key/DB name/data, or wrong DUPFIXED size
//*The specified DBI was changed unexpectedly
//*Unexpected problem - txn should abort
//*The last defined error code
//*@}
// Statistics for a database in the environment
// struct MDB_stat {
// 	//* Size of a database page.									This is currently the same for all databases.
// 	ms_psize u32
// 	//* Depth (height) of the B-tree
// 	ms_depth u32
// 	//* Number of internal (non-leaf) pages
// 	ms_branch_pages Mdb_size_t
// 	//* Number of leaf pages
// 	ms_leaf_pages Mdb_size_t
// 	//* Number of overflow pages
// 	ms_overflow_pages Mdb_size_t
// 	//* Number of data items
// 	ms_entries Mdb_size_t
// }

// Information about the environment
// struct MDB_envinfo {
// 	//* Address of map, if fixed
// 	me_mapaddr voidptr
// 	//* Size of the data memory map
// 	me_mapsize Mdb_size_t
// 	//* ID of the last used page
// 	me_last_pgno Mdb_size_t
// 	//* ID of the last committed transaction
// 	me_last_txnid Mdb_size_t
// 	//* max reader slots in the environment
// 	me_maxreaders u32
// 	//* max reader slots used in the environment
// 	me_numreaders u32
// }

// Return the LMDB library version information.
// @param[out] major if non-NULL, the library major version number is copied here
// @param[out] minor if non-NULL, the library minor version number is copied here
// @param[out] patch if non-NULL, the library patch version number is copied here
// @retval "version string" The library version as a string
//
pub fn mdb_version(major &int, minor &int, patch &int) &char {
	return C.mdb_version(major, minor, patch)
}

fn C.mdb_version(major &int, minor &int, patch &int) &char

// Return a string describing a given error code.
// This function is a superset of the ANSI C X3.159-1989 (ANSI C) strerror(3)
// function. If the error code is greater than or equal to 0, then the string
// returned by the system function strerror(3) is returned. If the error code
// is less than 0, an error string corresponding to the LMDB library error is
// returned. See @ref errors for a list of LMDB-specific error codes.
// @param[in] err The error code
// @retval "error message" The description of the error
//
pub fn mdb_strerror(err int) &char {
	return C.mdb_strerror(err)
}

fn C.mdb_strerror(err int) &char

// Create an LMDB environment handle.
// This function allocates memory for a `#MDB_env` structure. To release
// the allocated memory and discard the handle, call `#mdb_env_close()`.
// Before the handle may be used, it must be opened using `#mdb_env_open()`.
// Various other options may also need to be set before opening the handle,
// e.g. `#mdb_env_set_mapsize()`, `#mdb_env_set_maxreaders()`, `#mdb_env_set_maxdbs()`,
// depending on usage requirements.
// @param[out] env The address where the new handle will be stored
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_create(env &&Mdb_env) int {
	return C.mdb_env_create(env)
}

fn C.mdb_env_create(env &&Mdb_env) int

// Open an environment handle.
// If this function fails, `#mdb_env_close()` must be called to discard the `#MDB_env` handle.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] path The directory in which the database files reside. This
// directory must already exist and be writable.
// @param[in] flags Special options for this environment. This parameter
// must be set to 0 or by bitwise OR'ing together one or more of the
// values described here.
// Flags set by mdb_env_set_flags() are also used.
// <ul>
// <li>#MDB_FIXEDMAP
//      use a fixed address for the mmap region. This flag must be specified
//      when creating the environment, and is stored persistently in the environment.
// 	If successful, the memory map will always reside at the same virtual address
// 	and pointers used to reference data items in the database will be constant
// 	across multiple invocations. This option may not always work, depending on
// 	how the operating system has allocated memory to shared libraries and other uses.
// 	The feature is highly experimental.
// <li>#MDB_NOSUBDIR
// 	By default, LMDB creates its environment in a directory whose
// 	pathname is given in \b path, and creates its data and lock files
// 	under that directory. With this option, \b path is used as-is for
// 	the database main data file. The database lock file is the \b path
// 	with "-lock" appended.
// <li>#MDB_RDONLY
// 	Open the environment in read-only mode. No write operations will be
// 	allowed. LMDB will still modify the lock file - except on read-only
// 	filesystems, where LMDB does not use locks.
// <li>#MDB_WRITEMAP
// 	Use a writeable memory map unless MDB_RDONLY is set. This uses
// 	fewer mallocs but loses protection from application bugs
// 	like wild pointer writes and other bad updates into the database.
// 	This may be slightly faster for DBs that fit entirely in RAM, but
// 	is slower for DBs larger than RAM.
// 	Incompatible with nested transactions.
// 	Do not mix processes with and without MDB_WRITEMAP on the same
// 	environment.  This can defeat durability (#mdb_env_sync etc).
// <li>#MDB_NOMETASYNC
// 	Flush system buffers to disk only once per transaction, omit the
// 	metadata flush. Defer that until the system flushes files to disk,
// 	or next non-MDB_RDONLY commit or #mdb_env_sync(). This optimization
// 	maintains database integrity, but a system crash may undo the last
// 	committed transaction. I.e. it preserves the ACI (atomicity,
// 	consistency, isolation) but not D (durability) database property.
// 	This flag may be changed at any time using #mdb_env_set_flags().
// <li>#MDB_NOSYNC
// 	Don't flush system buffers to disk when committing a transaction.
// 	This optimization means a system crash can corrupt the database or
// 	lose the last transactions if buffers are not yet flushed to disk.
// 	The risk is governed by how often the system flushes dirty buffers
// 	to disk and how often #mdb_env_sync() is called.  However, if the
// 	filesystem preserves write order and the #MDB_WRITEMAP flag is not
// 	used, transactions exhibit ACI (atomicity, consistency, isolation)
// 	properties and only lose D (durability).  I.e. database integrity
// 	is maintained, but a system crash may undo the final transactions.
// 	Note that (#MDB_NOSYNC | #MDB_WRITEMAP) leaves the system with no
// 	hint for when to write transactions to disk, unless #mdb_env_sync()
// 	is called. (#MDB_MAPASYNC | #MDB_WRITEMAP) may be preferable.
// 	This flag may be changed at any time using #mdb_env_set_flags().
// <li>#MDB_MAPASYNC
// 	When using #MDB_WRITEMAP, use asynchronous flushes to disk.
// 	As with #MDB_NOSYNC, a system crash can then corrupt the
// 	database or lose the last transactions. Calling #mdb_env_sync()
// 	ensures on-disk database integrity until next commit.
// 	This flag may be changed at any time using #mdb_env_set_flags().
// <li>#MDB_NOTLS
// 	Don't use Thread-Local Storage. Tie reader locktable slots to
// 	#MDB_txn objects instead of to threads. I.e. #mdb_txn_reset() keeps
// 	the slot reserved for the #MDB_txn object. A thread may use parallel
// 	read-only transactions. A read-only transaction may span threads if
// 	the user synchronizes its use. Applications that multiplex many
// 	user threads over individual OS threads need this option. Such an
// 	application must also serialize the write transactions in an OS
// 	thread, since LMDB's write locking is unaware of the user threads.
// <li>#MDB_NOLOCK
// 	Don't do any locking. If concurrent access is anticipated, the
// 	caller must manage all concurrency itself. For proper operation
// 	the caller must enforce single-writer semantics, and must ensure
// 	that no readers are using old transactions while a writer is
// 	active. The simplest approach is to use an exclusive lock so that
// 	no readers may be active at all when a writer begins.
// <li>#MDB_NORDAHEAD
// 	Turn off readahead. Most operating systems perform readahead on
// 	read requests by default. This option turns it off if the OS
// 	supports it. Turning it off may help random read performance
// 	when the DB is larger than RAM and system RAM is full.
// 	The option is not implemented on Windows.
// <li>#MDB_NOMEMINIT
// 	Don't initialize malloc'd memory before writing to unused spaces
// 	in the data file. By default, memory for pages written to the data
// 	file is obtained using malloc. While these pages may be reused in
// 	subsequent transactions, freshly malloc'd pages will be initialized
// 	to zeroes before use. This avoids persisting leftover data from other
// 	code (that used the heap and subsequently freed the memory) into the
// 	data file. Note that many other system libraries may allocate
// 	and free memory from the heap for arbitrary uses. E.g., stdio may
// 	use the heap for file I/O buffers. This initialization step has a
// 	modest performance cost so some applications may want to disable
// 	it using this flag. This option can be a problem for applications
// 	which handle sensitive data like passwords, and it makes memory
// 	checkers like Valgrind noisy. This flag is not needed with #MDB_WRITEMAP,
// 	which writes directly to the mmap instead of using malloc for pages. The
// 	initialization is also skipped if #MDB_RESERVE is used; the
// 	caller is expected to overwrite all of the memory that was
// 	reserved in that case.
// 	This flag may be changed at any time using #mdb_env_set_flags().
// <li>#MDB_PREVSNAPSHOT
// 	Open the environment with the previous snapshot rather than the latest
// 	one. This loses the latest transaction, but may help work around some
// 	types of corruption. If opened with write access, this must be the
// 	only process using the environment. This flag is automatically reset
// 	after a write transaction is successfully committed.
// </ul>
// @param[in] mode The UNIX permissions to set on created files and semaphores.
// This parameter is ignored on Windows.
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_VERSION_MISMATCH - the version of the LMDB library doesn't match the
// version that created the database environment.
// <li>#MDB_INVALID - the environment file headers are corrupted.
// <li>ENOENT - the directory specified by the path parameter doesn't exist.
// <li>EACCES - the user didn't have permission to access the environment files.
// <li>EAGAIN - the environment was locked by another process.
// </ul>
//
pub fn mdb_env_open(env &Mdb_env, const_path &char, flags u32, mode Mdb_mode_t) int {
	return C.mdb_env_open(env, const_path, flags, mode)
}

fn C.mdb_env_open(env &Mdb_env, const_path &char, flags u32, mode Mdb_mode_t) int

// Copy an LMDB environment to the specified path.
// This function may be used to make a backup of an existing environment.
// No lockfile is created, since it gets recreated at need.
// @note This call can trigger significant file size growth if run in
// parallel with write transactions, because it employs a read-only
// transaction. See long-lived transactions under @ref caveats_sec.
// @param[in] env An environment handle returned by `#mdb_env_create()`. It
// must have already been opened successfully.
// @param[in] path The directory in which the copy will reside. This
// directory must already exist and be writable but must otherwise be
// empty.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_copy(env &Mdb_env, const_path &char) int {
	return C.mdb_env_copy(env, const_path)
}

fn C.mdb_env_copy(env &Mdb_env, const_path &char) int

// Copy an LMDB environment to the specified file descriptor.
// This function may be used to make a backup of an existing environment.
// No lockfile is created, since it gets recreated at need.
// @note This call can trigger significant file size growth if run in
// parallel with write transactions, because it employs a read-only
// transaction. See long-lived transactions under @ref caveats_sec.
// @param[in] env An environment handle returned by `#mdb_env_create()`. It
// must have already been opened successfully.
// @param[in] fd The filedescriptor to write the copy to. It must
// have already been opened for Write access.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_copyfd(env &Mdb_env, fd Mdb_filehandle_t) int {
	return C.mdb_env_copyfd(env, fd)
}

fn C.mdb_env_copyfd(env &Mdb_env, fd Mdb_filehandle_t) int

// Copy an LMDB environment to the specified path, with options.
// This function may be used to make a backup of an existing environment.
// No lockfile is created, since it gets recreated at need.
// @note This call can trigger significant file size growth if run in
// parallel with write transactions, because it employs a read-only
// transaction. See long-lived transactions under @ref caveats_sec.
// @param[in] env An environment handle returned by `#mdb_env_create()`. It
// must have already been opened successfully.
// @param[in] path The directory in which the copy will reside. This
// directory must already exist and be writable but must otherwise be
// empty.
// @param[in] flags Special options for this operation. This parameter
// must be set to 0 or by bitwise OR'ing together one or more of the
// values described here.
// <ul>
// <li>#MDB_CP_COMPACT - Perform compaction while copying: omit free
// 	pages and sequentially renumber all pages in output. This option
// 	consumes more CPU and runs more slowly than the default.
// 	Currently it fails if the environment has suffered a page leak.
// </ul>
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_copy2(env &Mdb_env, const_path &char, flags u32) int {
	return C.mdb_env_copy2(env, const_path, flags)
}

fn C.mdb_env_copy2(env &Mdb_env, const_path &char, flags u32) int

// Copy an LMDB environment to the specified file descriptor,
// with options.
// This function may be used to make a backup of an existing environment.
// No lockfile is created, since it gets recreated at need. See
// #mdb_env_copy2() for further details.
// @note This call can trigger significant file size growth if run in
// parallel with write transactions, because it employs a read-only
// transaction. See long-lived transactions under @ref caveats_sec.
// @param[in] env An environment handle returned by `#mdb_env_create()`. It
// must have already been opened successfully.
// @param[in] fd The filedescriptor to write the copy to. It must
// have already been opened for Write access.
// @param[in] flags Special options for this operation.
// See #mdb_env_copy2() for options.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_copyfd2(env &Mdb_env, fd Mdb_filehandle_t, flags u32) int {
	return C.mdb_env_copyfd2(env, fd, flags)
}

fn C.mdb_env_copyfd2(env &Mdb_env, fd Mdb_filehandle_t, flags u32) int

// Return statistics about the LMDB environment.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] stat The address of an #MDB_stat structure
// 	where the statistics will be copied
//
pub fn mdb_env_stat(env &Mdb_env, stat &Mdb_stat) int {
	return C.mdb_env_stat(env, stat)
}

fn C.mdb_env_stat(env &Mdb_env, stat &Mdb_stat) int

// Return information about the LMDB environment.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] stat The address of an #MDB_envinfo structure
// 	where the information will be copied
//
pub fn mdb_env_info(env &Mdb_env, stat &Mdb_envinfo) int {
	return C.mdb_env_info(env, stat)
}

fn C.mdb_env_info(env &Mdb_env, stat &Mdb_envinfo) int

// Flush the data buffers to disk.
// Data is always written to disk when #mdb_txn_commit() is called,
// but the operating system may keep it buffered. LMDB always flushes
// the OS buffers upon commit as well, unless the environment was
// opened with #MDB_NOSYNC or in part #MDB_NOMETASYNC. This call is
// not valid if the environment was opened with #MDB_RDONLY.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] force If non-zero, force a synchronous flush.  Otherwise
//  if the environment has the #MDB_NOSYNC flag set the flushes
// will be omitted, and with #MDB_MAPASYNC they will be asynchronous.
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EACCES - the environment is read-only.
// <li>EINVAL - an invalid parameter was specified.
// <li>EIO - an error occurred during synchronization.
// </ul>
//
pub fn mdb_env_sync(env &Mdb_env, force int) int {
	return C.mdb_env_sync(env, force)
}

fn C.mdb_env_sync(env &Mdb_env, force int) int

// Close the environment and release the memory map.
// Only a single thread may call this function. All transactions, databases,
// and cursors must already be closed before calling this function. Attempts to
// use any such handles after calling this function will cause a SIGSEGV.
// The environment handle will be freed and must not be used again after this call.
// @param[in] env An environment handle returned by `#mdb_env_create()`
//
pub fn mdb_env_close(env &Mdb_env) {
	C.mdb_env_close(env)
}

fn C.mdb_env_close(env &Mdb_env)

// Set environment flags.
// This may be used to set some flags in addition to those from
// `#mdb_env_open()`, or to unset these flags.  If several threads
// change the flags at the same time, the result is undefined.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] flags The flags to change, bitwise OR'ed together
// @param[in] onoff A non-zero value sets the flags, zero clears them.
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_env_set_flags(env &Mdb_env, flags u32, onoff int) int {
	return C.mdb_env_set_flags(env, flags, onoff)
}

fn C.mdb_env_set_flags(env &Mdb_env, flags u32, onoff int) int

// Get environment flags.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] flags The address of an integer to store the flags
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_env_get_flags(env &Mdb_env, flags &u32) int {
	return C.mdb_env_get_flags(env, flags)
}

fn C.mdb_env_get_flags(env &Mdb_env, flags &u32) int

// Return the path that was used in `#mdb_env_open()`.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] path Address of a string pointer to contain the path. This
// is the actual string in the environment, not a copy. It should not be
// altered in any way.
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_env_get_path(env &Mdb_env, const_path &&char) int {
	return C.mdb_env_get_path(env, const_path)
}

fn C.mdb_env_get_path(env &Mdb_env, const_path &&char) int

// Return the filedescriptor for the given environment.
// This function may be called after fork(), so the descriptor can be
// closed before exec*).  Other LMDB file descriptors have FD_CLOEXEC.
// (Until LMDB 0.9.18, only the lockfile had that.)
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] fd Address of a mdb_filehandle_t to contain the descriptor.
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_env_get_fd(env &Mdb_env, fd &Mdb_filehandle_t) int {
	return C.mdb_env_get_fd(env, fd)
}

fn C.mdb_env_get_fd(env &Mdb_env, fd &Mdb_filehandle_t) int

// Set the size of the memory map to use for this environment.
// The size should be a multiple of the OS page size. The default is
// 10485760 bytes. The size of the memory map is also the maximum size
// of the database. The value should be chosen as large as possible,
// to accommodate future growth of the database.
// This function should be called after `#mdb_env_create()` and before `#mdb_env_open()`.
// It may be called at later times if no transactions are active in
// this process. Note that the library does not check for this condition,
// the caller must ensure it explicitly.
// The new size takes effect immediately for the current process but
// will not be persisted to any others until a write transaction has been
// committed by the current process. Also, only mapsize increases are
// persisted into the environment.
// If the mapsize is increased by another process, and data has grown
// beyond the range of the current mapsize, #mdb_txn_begin() will
// return #MDB_MAP_RESIZED. This function may be called with a size
// of zero to adopt the new size.
// Any attempt to set a size smaller than the space already consumed
// by the environment will be silently changed to the current size of the used space.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] size The size in bytes
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified, or the environment has
//   	an active write transaction.
// </ul>
//
pub fn mdb_env_set_mapsize(env &Mdb_env, size Mdb_size_t) int {
	return C.mdb_env_set_mapsize(env, size)
}

fn C.mdb_env_set_mapsize(env &Mdb_env, size Mdb_size_t) int

// Set the maximum number of threads/reader slots for the environment.
// This defines the number of slots in the lock table that is used to track readers in the
// the environment. The default is 126.
// Starting a read-only transaction normally ties a lock table slot to the
// current thread until the environment closes or the thread exits. If
// MDB_NOTLS is in use, #mdb_txn_begin() instead ties the slot to the
// MDB_txn object until it or the `#MDB_env` object is destroyed.
// This function may only be called after `#mdb_env_create()` and before `#mdb_env_open()`.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] readers The maximum number of reader lock table slots
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified, or the environment is already open.
// </ul>
//
pub fn mdb_env_set_maxreaders(env &Mdb_env, readers u32) int {
	return C.mdb_env_set_maxreaders(env, readers)
}

fn C.mdb_env_set_maxreaders(env &Mdb_env, readers u32) int

// Get the maximum number of threads/reader slots for the environment.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] readers Address of an integer to store the number of readers
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_env_get_maxreaders(env &Mdb_env, readers &u32) int {
	return C.mdb_env_get_maxreaders(env, readers)
}

fn C.mdb_env_get_maxreaders(env &Mdb_env, readers &u32) int

// Set the maximum number of named databases for the environment.
// This function is only needed if multiple databases will be used in the
// environment. Simpler applications that use the environment as a single
// unnamed database can ignore this option.
// This function may only be called after `#mdb_env_create()` and before `#mdb_env_open()`.
// Currently a moderate number of slots are cheap but a huge number gets
// expensive: 7-120 words per transaction, and every #mdb_dbi_open()
// does a linear search of the opened slots.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] dbs The maximum number of databases
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified, or the environment is already open.
// </ul>
//
pub fn mdb_env_set_maxdbs(env &Mdb_env, dbs Mdb_dbi) int {
	return C.mdb_env_set_maxdbs(env, dbs)
}

fn C.mdb_env_set_maxdbs(env &Mdb_env, dbs Mdb_dbi) int

// Get the maximum size of keys and #MDB_DUPSORT data we can write.
// Depends on the compile-time constant #MDB_MAXKEYSIZE. Default 511.
// See @ref MDB_val.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @return The maximum size of a key we can write
//
pub fn mdb_env_get_maxkeysize(env &Mdb_env) int {
	return C.mdb_env_get_maxkeysize(env)
}

fn C.mdb_env_get_maxkeysize(env &Mdb_env) int

// Set application information associated with the #MDB_env.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] ctx An arbitrary pointer for whatever the application needs.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_set_userctx(env &Mdb_env, ctx voidptr) int {
	return C.mdb_env_set_userctx(env, ctx)
}

fn C.mdb_env_set_userctx(env &Mdb_env, ctx voidptr) int

// Get the application information associated with the #MDB_env.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @return The pointer set by #mdb_env_set_userctx().
//
pub fn mdb_env_get_userctx(env &Mdb_env) voidptr {
	return C.mdb_env_get_userctx(env)
}

fn C.mdb_env_get_userctx(env &Mdb_env) voidptr

// A callback function for most LMDB assert() failures,
// called before printing the message and aborting.
// @param[in] env An environment handle returned by `#mdb_env_create()`.
// @param[in] msg The assertion message, not including newline.
//
type MDB_assert_func = fn (env &Mdb_env, const_msg &char)

//*Set or reset the assert() callback of the environment.
// Disabled if liblmdb is built with NDEBUG.
// @note This hack should become obsolete as lmdb's error handling matures.
// @param[in] env An environment handle returned by `#mdb_env_create()`.
// @param[in] func An #MDB_assert_func function, or 0.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_env_set_assert(env &Mdb_env, func MDB_assert_func) int {
	return C.mdb_env_set_assert(env, func)
}

fn C.mdb_env_set_assert(env &Mdb_env, func MDB_assert_func) int

// Create a transaction for use with the environment.
// The transaction handle may be discarded using #mdb_txn_abort() or #mdb_txn_commit().
// @note A transaction and its cursors must only be used by a single
// thread, and a thread may only have a single transaction at a time.
// If #MDB_NOTLS is in use, this does not apply to read-only transactions.
// @note Cursors may not span transactions.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] parent If this parameter is non-NULL, the new transaction
// will be a nested transaction, with the transaction indicated by \b parent
// as its parent. Transactions may be nested to any level. A parent
// transaction and its cursors may not issue any other operations than
// mdb_txn_commit and mdb_txn_abort while it has active child transactions.
// @param[in] flags Special options for this transaction. This parameter
// must be set to 0 or by bitwise OR'ing together one or more of the
// values described here.
// <ul>
// <li>#MDB_RDONLY
// 	This transaction will not perform any write operations.
// <li>#MDB_NOSYNC
// 	Don't flush system buffers to disk when committing this transaction.
// <li>#MDB_NOMETASYNC
// 	Flush system buffers but omit metadata flush when committing this transaction.
// </ul>
// @param[out] txn Address where the new #MDB_txn handle will be stored
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_PANIC - a fatal error occurred earlier and the environment
// 	must be shut down.
// <li>#MDB_MAP_RESIZED - another process wrote data beyond this MDB_env's
// 	mapsize and this environment's map must be resized as well.
// 	See `#mdb_env_set_mapsize()`.
// <li>#MDB_READERS_FULL - a read-only transaction was requested and
// 	the reader lock table is full. See `#mdb_env_set_maxreaders()`.
// <li>ENOMEM - out of memory.
// </ul>
//
pub fn mdb_txn_begin(env &Mdb_env, parent &Mdb_txn, flags u32, txn &&Mdb_txn) int {
	return C.mdb_txn_begin(env, parent, flags, txn)
}

fn C.mdb_txn_begin(env &Mdb_env, parent &Mdb_txn, flags u32, txn &&Mdb_txn) int

// Returns the transaction's #MDB_env
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
//
pub fn mdb_txn_env(txn &Mdb_txn) &Mdb_env {
	return C.mdb_txn_env(txn)
}

fn C.mdb_txn_env(txn &Mdb_txn) &Mdb_env

// Return the transaction's ID.
// This returns the identifier associated with this transaction. For a
// read-only transaction, this corresponds to the snapshot being read;
// concurrent readers will frequently have the same transaction ID.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @return A transaction ID, valid if input is an active transaction.
//
pub fn mdb_txn_id(txn &Mdb_txn) Mdb_size_t {
	return C.mdb_txn_id(txn)
}

fn C.mdb_txn_id(txn &Mdb_txn) Mdb_size_t

// Commit all the operations of a transaction into the database.
// The transaction handle is freed. It and its cursors must not be used
// again after this call, except with #mdb_cursor_renew().
// @note Earlier documentation incorrectly said all cursors would be freed.
// Only write-transactions free cursors.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// <li>ENOSPC - no more disk space.
// <li>EIO - a low-level I/O error occurred while writing.
// <li>ENOMEM - out of memory.
// </ul>
//
pub fn mdb_txn_commit(txn &Mdb_txn) int {
	return C.mdb_txn_commit(txn)
}

fn C.mdb_txn_commit(txn &Mdb_txn) int

// Abandon all the operations of the transaction instead of saving them.
// The transaction handle is freed. It and its cursors must not be used
// again after this call, except with #mdb_cursor_renew().
// @note Earlier documentation incorrectly said all cursors would be freed.
// Only write-transactions free cursors.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
//
pub fn mdb_txn_abort(txn &Mdb_txn) {
	C.mdb_txn_abort(txn)
}

fn C.mdb_txn_abort(txn &Mdb_txn)

// Reset a read-only transaction.
// Abort the transaction like #mdb_txn_abort(), but keep the transaction
// handle. #mdb_txn_renew() may reuse the handle. This saves allocation
// overhead if the process will start a new read-only transaction soon,
// and also locking overhead if #MDB_NOTLS is in use. The reader table
// lock is released, but the table slot stays tied to its thread or
// #MDB_txn. Use mdb_txn_abort() to discard a reset handle, and to free
// its lock table slot if MDB_NOTLS is in use.
// Cursors opened within the transaction must not be used
// again after this call, except with #mdb_cursor_renew().
// Reader locks generally don't interfere with writers, but they keep old
// versions of database pages allocated. Thus they prevent the old pages
// from being reused when writers commit new data, and so under heavy load
// the database size may grow much more rapidly than otherwise.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
//
pub fn mdb_txn_reset(txn &Mdb_txn) {
	C.mdb_txn_reset(txn)
}

fn C.mdb_txn_reset(txn &Mdb_txn)

// Renew a read-only transaction.
// This acquires a new reader lock for a transaction handle that had been
// released by #mdb_txn_reset(). It must be called before a reset transaction
// may be used again.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_PANIC - a fatal error occurred earlier and the environment
// 	must be shut down.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_txn_renew(txn &Mdb_txn) int {
	return C.mdb_txn_renew(txn)
}

fn C.mdb_txn_renew(txn &Mdb_txn) int

//*Compat with version <= 0.9.4, avoid clash with libmdb from MDB Tools project
//*Compat with version <= 0.9.4, avoid clash with libmdb from MDB Tools project
// Open a database in the environment.
// A database handle denotes the name and parameters of a database,
// independently of whether such a database exists.
// The database handle may be discarded by calling #mdb_dbi_close().
// The old database handle is returned if the database was already open.
// The handle may only be closed once.
// The database handle will be private to the current transaction until
// the transaction is successfully committed. If the transaction is
// aborted the handle will be closed automatically.
// After a successful commit the handle will reside in the shared
// environment, and may be used by other transactions.
// This function must not be called from multiple concurrent
// transactions in the same process. A transaction that uses
// this function must finish (either commit or abort) before
// any other transaction in the process may use this function.
// To use named databases (with name != NULL), `#mdb_env_set_maxdbs()`
// must be called before opening the environment.  Database names are
// keys in the unnamed database, and may be read but not written.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] name The name of the database to open. If only a single
// 	database is needed in the environment, this value may be NULL.
// @param[in] flags Special options for this database. This parameter
// must be set to 0 or by bitwise OR'ing together one or more of the
// values described here.
// <ul>
// <li>#MDB_REVERSEKEY
// 	Keys are strings to be compared in reverse order, from the end
// 	of the strings to the beginning. By default, Keys are treated as strings and
// 	compared from beginning to end.
// <li>#MDB_DUPSORT
// 	Duplicate keys may be used in the database. (Or, from another perspective,
// 	keys may have multiple data items, stored in sorted order.) By default
// 	keys must be unique and may have only a single data item.
// <li>#MDB_INTEGERKEY
// 	Keys are binary integers in native byte order, either unsigned int
// 	or `#mdb_size_t`, and will be sorted as such.
// 	(lmdb expects 32-bit int <= size_t <= 32/64-bit mdb_size_t.)
// 	The keys must all be of the same size.
// <li>#MDB_DUPFIXED
// 	This flag may only be used in combination with #MDB_DUPSORT. This option
// 	tells the library that the data items for this database are all the same
// 	size, which allows further optimizations in storage and retrieval. When
// 	all data items are the same size, the #MDB_GET_MULTIPLE, #MDB_NEXT_MULTIPLE
// 	and #MDB_PREV_MULTIPLE cursor operations may be used to retrieve multiple
// 	items at once.
// <li>#MDB_INTEGERDUP
// 	This option specifies that duplicate data items are binary integers,
// 	similar to #MDB_INTEGERKEY keys.
// <li>#MDB_REVERSEDUP
// 	This option specifies that duplicate data items should be compared as
// 	strings in reverse order.
// <li>#MDB_CREATE
// 	Create the named database if it doesn't exist. This option is not
// 	allowed in a read-only transaction or a read-only environment.
// </ul>
// @param[out] dbi Address where the new #Mdb_dbi handle will be stored
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_NOTFOUND - the specified database doesn't exist in the environment
// 	and #MDB_CREATE was not specified.
// <li>#MDB_DBS_FULL - too many databases have been opened. See `#mdb_env_set_maxdbs()`.
// </ul>
//
pub fn mdb_dbi_open(txn &Mdb_txn, const_name &char, flags u32, dbi &Mdb_dbi) int {
	return C.mdb_dbi_open(txn, const_name, flags, dbi)
}

fn C.mdb_dbi_open(txn &Mdb_txn, const_name &char, flags u32, dbi &Mdb_dbi) int

// Retrieve statistics for a database.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[out] stat The address of an #MDB_stat structure
// 	where the statistics will be copied
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_stat(txn &Mdb_txn, dbi Mdb_dbi, stat &Mdb_stat) int {
	return C.mdb_stat(txn, dbi, stat)
}

fn C.mdb_stat(txn &Mdb_txn, dbi Mdb_dbi, stat &Mdb_stat) int

// Retrieve the DB flags for a database handle.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[out] flags Address where the flags will be returned.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_dbi_flags(txn &Mdb_txn, dbi Mdb_dbi, flags &u32) int {
	return C.mdb_dbi_flags(txn, dbi, flags)
}

fn C.mdb_dbi_flags(txn &Mdb_txn, dbi Mdb_dbi, flags &u32) int

// Close a database handle. Normally unnecessary. Use with care:
// This call is not mutex protected. Handles should only be closed by
// a single thread, and only if no other threads are going to reference
// the database handle or one of its cursors any further. Do not close
// a handle if an existing transaction has modified its database.
// Doing so can cause misbehavior from database corruption to errors
// like MDB_BAD_VALSIZE (since the DB name is gone).
// Closing a database handle is not necessary, but lets #mdb_dbi_open()
// reuse the handle value.  Usually it's better to set a bigger
// `#mdb_env_set_maxdbs()`, unless that value would be large.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] dbi A database handle returned by #mdb_dbi_open()
//
pub fn mdb_dbi_close(env &Mdb_env, dbi Mdb_dbi) {
	C.mdb_dbi_close(env, dbi)
}

fn C.mdb_dbi_close(env &Mdb_env, dbi Mdb_dbi)

// Empty or delete+close a database.
// See #mdb_dbi_close() for restrictions about closing the DB handle.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] del 0 to empty the DB, 1 to delete it from the
// environment and close the DB handle.
// @return A non-zero error value on failure and 0 on success.
//
pub fn mdb_drop(txn &Mdb_txn, dbi Mdb_dbi, del int) int {
	return C.mdb_drop(txn, dbi, del)
}

fn C.mdb_drop(txn &Mdb_txn, dbi Mdb_dbi, del int) int

// Set a custom key comparison function for a database.
// The comparison function is called whenever it is necessary to compare a
// key specified by the application with a key currently stored in the database.
// If no comparison function is specified, and no special key flags were specified
// with #mdb_dbi_open(), the keys are compared lexically, with shorter keys collating
// before longer keys.
// @warning This function must be called before any data access functions are used,
// otherwise data corruption may occur. The same comparison function must be used by every
// program accessing the database, every time the database is used.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] cmp A #MDB_cmp_func function
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_set_compare(txn &Mdb_txn, dbi Mdb_dbi, cmp MDB_cmp_func) int {
	return C.mdb_set_compare(txn, dbi, cmp)
}

fn C.mdb_set_compare(txn &Mdb_txn, dbi Mdb_dbi, cmp MDB_cmp_func) int

// Set a custom data comparison function for a #MDB_DUPSORT database.
// This comparison function is called whenever it is necessary to compare a data
// item specified by the application with a data item currently stored in the database.
// This function only takes effect if the database was opened with the #MDB_DUPSORT
// flag.
// If no comparison function is specified, and no special key flags were specified
// with #mdb_dbi_open(), the data items are compared lexically, with shorter items collating
// before longer items.
// @warning This function must be called before any data access functions are used,
// otherwise data corruption may occur. The same comparison function must be used by every
// program accessing the database, every time the database is used.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] cmp A #MDB_cmp_func function
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_set_dupsort(txn &Mdb_txn, dbi Mdb_dbi, cmp MDB_cmp_func) int {
	return C.mdb_set_dupsort(txn, dbi, cmp)
}

fn C.mdb_set_dupsort(txn &Mdb_txn, dbi Mdb_dbi, cmp MDB_cmp_func) int

// Set a relocation function for a #MDB_FIXEDMAP database.
// @todo The relocation function is called whenever it is necessary to move the data
// of an item to a different position in the database (e.g. through tree
// balancing operations, shifts as a result of adds or deletes, etc.). It is
// intended to allow address/position-dependent data items to be stored in
// a database in an environment opened with the #MDB_FIXEDMAP option.
// Currently the relocation feature is unimplemented and setting
// this function has no effect.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] rel A #MDB_rel_func function
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_set_relfunc(txn &Mdb_txn, dbi Mdb_dbi, rel MDB_rel_func) int {
	return C.mdb_set_relfunc(txn, dbi, rel)
}

fn C.mdb_set_relfunc(txn &Mdb_txn, dbi Mdb_dbi, rel MDB_rel_func) int

// Set a context pointer for a #MDB_FIXEDMAP database's relocation function.
// See #mdb_set_relfunc and #MDB_rel_func for more details.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] ctx An arbitrary pointer for whatever the application needs.
// It will be passed to the callback function set by #mdb_set_relfunc
// as its \b relctx parameter whenever the callback is invoked.
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_set_relctx(txn &Mdb_txn, dbi Mdb_dbi, ctx voidptr) int {
	return C.mdb_set_relctx(txn, dbi, ctx)
}

fn C.mdb_set_relctx(txn &Mdb_txn, dbi Mdb_dbi, ctx voidptr) int

// Get items from a database.
// This function retrieves key/data pairs from the database. The address
// and length of the data associated with the specified \b key are returned
// in the structure to which \b data refers.
// If the database supports duplicate keys (#MDB_DUPSORT) then the
// first data item for the key will be returned. Retrieval of other
// items requires the use of #mdb_cursor_get().
// @note The memory pointed to by the returned values is owned by the
// database. The caller need not dispose of the memory, and may not
// modify it in any way. For values returned in a read-only transaction
// any modification attempts will cause a SIGSEGV.
// @note Values returned from the database are valid only until a
// subsequent update operation, or the end of the transaction.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] key The key to search for in the database
// @param[out] data The data corresponding to the key
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_NOTFOUND - the key was not in the database.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_get(txn &Mdb_txn, dbi Mdb_dbi, key &Mdb_val, data &Mdb_val) int {
	return C.mdb_get(txn, dbi, key, data)
}

fn C.mdb_get(txn &Mdb_txn, dbi Mdb_dbi, key &Mdb_val, data &Mdb_val) int

// Store items into a database.
// This function stores key/data pairs in the database. The default behavior
// is to enter the new key/data pair, replacing any previously existing key
// if duplicates are disallowed, or adding a duplicate data item if
// duplicates are allowed (#MDB_DUPSORT).
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] key The key to store in the database
// @param[in,out] data The data to store
// @param[in] flags Special options for this operation. This parameter
// must be set to 0 or by bitwise OR'ing together one or more of the
// values described here.
// <ul>
// <li>#MDB_NODUPDATA - enter the new key/data pair only if it does not
// 	already appear in the database. This flag may only be specified
// 	if the database was opened with #MDB_DUPSORT. The function will
// 	return #MDB_KEYEXIST if the key/data pair already appears in the
// 	database.
// <li>#MDB_NOOVERWRITE - enter the new key/data pair only if the key
// 	does not already appear in the database. The function will return
// 	#MDB_KEYEXIST if the key already appears in the database, even if
// 	the database supports duplicates (#MDB_DUPSORT). The \b data
// 	parameter will be set to point to the existing item.
// <li>#MDB_RESERVE - reserve space for data of the given size, but
// 	don't copy the given data. Instead, return a pointer to the
// 	reserved space, which the caller can fill in later - before
// 	the next update operation or the transaction ends. This saves
// 	an extra memcpy if the data is being generated later.
// 	LMDB does nothing else with this memory, the caller is expected
// 	to modify all of the space requested. This flag must not be
// 	specified if the database was opened with #MDB_DUPSORT.
// <li>#MDB_APPEND - append the given key/data pair to the end of the
// 	database. This option allows fast bulk loading when keys are
// 	already known to be in the correct order. Loading unsorted keys
// 	with this flag will cause a #MDB_KEYEXIST error.
// <li>#MDB_APPENDDUP - as above, but for sorted dup data.
// </ul>
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_MAP_FULL - the database is full, see `#mdb_env_set_mapsize()`.
// <li>#MDB_TXN_FULL - the transaction has too many dirty pages.
// <li>EACCES - an attempt was made to write in a read-only transaction.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_put(txn &Mdb_txn, dbi Mdb_dbi, key &Mdb_val, data &Mdb_val, flags u32) int {
	return C.mdb_put(txn, dbi, key, data, flags)
}

fn C.mdb_put(txn &Mdb_txn, dbi Mdb_dbi, key &Mdb_val, data &Mdb_val, flags u32) int

// Delete items from a database.
// This function removes key/data pairs from the database.
// If the database does not support sorted duplicate data items
// (#MDB_DUPSORT) the data parameter is ignored.
// If the database supports sorted duplicates and the data parameter
// is NULL, all of the duplicate data items for the key will be
// deleted. Otherwise, if the data parameter is non-NULL
// only the matching data item will be deleted.
// This function will return #MDB_NOTFOUND if the specified key/data
// pair is not in the database.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] key The key to delete from the database
// @param[in] data The data to delete
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EACCES - an attempt was made to write in a read-only transaction.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_del(txn &Mdb_txn, dbi Mdb_dbi, key &Mdb_val, data &Mdb_val) int {
	return C.mdb_del(txn, dbi, key, data)
}

fn C.mdb_del(txn &Mdb_txn, dbi Mdb_dbi, key &Mdb_val, data &Mdb_val) int

// Create a cursor handle.
// A cursor is associated with a specific transaction and database.
// A cursor cannot be used when its database handle is closed.  Nor
// when its transaction has ended, except with #mdb_cursor_renew().
// It can be discarded with #mdb_cursor_close().
// A cursor in a write-transaction can be closed before its transaction
// ends, and will otherwise be closed when its transaction ends.
// A cursor in a read-only transaction must be closed explicitly, before
// or after its transaction ends. It can be reused with
// #mdb_cursor_renew() before finally closing it.
// @note Earlier documentation said that cursors in every transaction
// were closed when the transaction committed or aborted.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[out] cursor Address where the new #MDB_cursor handle will be stored
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_cursor_open(txn &Mdb_txn, dbi Mdb_dbi, cursor &&Mdb_cursor) int {
	return C.mdb_cursor_open(txn, dbi, cursor)
}

fn C.mdb_cursor_open(txn &Mdb_txn, dbi Mdb_dbi, cursor &&Mdb_cursor) int

// Close a cursor handle.
// The cursor handle will be freed and must not be used again after this call.
// Its transaction must still be live if it is a write-transaction.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
//
pub fn mdb_cursor_close(cursor &Mdb_cursor) {
	C.mdb_cursor_close(cursor)
}

fn C.mdb_cursor_close(cursor &Mdb_cursor)

// Renew a cursor handle.
// A cursor is associated with a specific transaction and database.
// Cursors that are only used in read-only
// transactions may be re-used, to avoid unnecessary malloc/free overhead.
// The cursor may be associated with a new read-only transaction, and
// referencing the same database handle as it was created with.
// This may be done whether the previous transaction is live or dead.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_cursor_renew(txn &Mdb_txn, cursor &Mdb_cursor) int {
	return C.mdb_cursor_renew(txn, cursor)
}

fn C.mdb_cursor_renew(txn &Mdb_txn, cursor &Mdb_cursor) int

// Return the cursor's transaction handle.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
//
pub fn mdb_cursor_txn(cursor &Mdb_cursor) &Mdb_txn {
	return C.mdb_cursor_txn(cursor)
}

fn C.mdb_cursor_txn(cursor &Mdb_cursor) &Mdb_txn

// Return the cursor's database handle.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
//
pub fn mdb_cursor_dbi(cursor &Mdb_cursor) Mdb_dbi {
	return C.mdb_cursor_dbi(cursor)
}

fn C.mdb_cursor_dbi(cursor &Mdb_cursor) Mdb_dbi

// Retrieve by cursor.
// This function retrieves key/data pairs from the database. The address and length
// of the key are returned in the object to which \b key refers (except for the
// case of the #MDB_SET option, in which the \b key object is unchanged), and
// the address and length of the data are returned in the object to which \b data
// refers.
// See #mdb_get() for restrictions on using the output values.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
// @param[in,out] key The key for a retrieved item
// @param[in,out] data The data of a retrieved item
// @param[in] op A cursor operation #MDB_cursor_op
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_NOTFOUND - no matching key found.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_cursor_get(cursor &Mdb_cursor, key &Mdb_val, data &Mdb_val, op Mdb_cursor_op) int {
	return C.mdb_cursor_get(cursor, key, data, int(op))
}

fn C.mdb_cursor_get(cursor &Mdb_cursor, key &Mdb_val, data &Mdb_val, op int) int

// Store by cursor.
// This function stores key/data pairs into the database.
// The cursor is positioned at the new item, or on failure usually near it.
// @note Earlier documentation incorrectly said errors would leave the
// state of the cursor unchanged.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
// @param[in] key The key operated on.
// @param[in] data The data operated on.
// @param[in] flags Options for this operation. This parameter
// must be set to 0 or one of the values described here.
// <ul>
// <li>#MDB_CURRENT - replace the item at the current cursor position.
// 	The \b key parameter must still be provided, and must match it.
// 	If using sorted duplicates (#MDB_DUPSORT) the data item must still
// 	sort into the same place. This is intended to be used when the
// 	new data is the same size as the old. Otherwise it will simply
// 	perform a delete of the old record followed by an insert.
// <li>#MDB_NODUPDATA - enter the new key/data pair only if it does not
// 	already appear in the database. This flag may only be specified
// 	if the database was opened with #MDB_DUPSORT. The function will
// 	return #MDB_KEYEXIST if the key/data pair already appears in the
// 	database.
// <li>#MDB_NOOVERWRITE - enter the new key/data pair only if the key
// 	does not already appear in the database. The function will return
// 	#MDB_KEYEXIST if the key already appears in the database, even if
// 	the database supports duplicates (#MDB_DUPSORT).
// <li>#MDB_RESERVE - reserve space for data of the given size, but
// 	don't copy the given data. Instead, return a pointer to the
// 	reserved space, which the caller can fill in later - before
// 	the next update operation or the transaction ends. This saves
// 	an extra memcpy if the data is being generated later. This flag
// 	must not be specified if the database was opened with #MDB_DUPSORT.
// <li>#MDB_APPEND - append the given key/data pair to the end of the
// 	database. No key comparisons are performed. This option allows
// 	fast bulk loading when keys are already known to be in the
// 	correct order. Loading unsorted keys with this flag will cause
// 	a #MDB_KEYEXIST error.
// <li>#MDB_APPENDDUP - as above, but for sorted dup data.
// <li>#MDB_MULTIPLE - store multiple contiguous data elements in a
// 	single request. This flag may only be specified if the database
// 	was opened with #MDB_DUPFIXED. The \b data argument must be an
// 	array of two MDB_vals. The mv_size of the first MDB_val must be
// 	the size of a single data element. The mv_data of the first MDB_val
// 	must point to the beginning of the array of contiguous data elements.
// 	The mv_size of the second MDB_val must be the count of the number
// 	of data elements to store. On return this field will be set to
// 	the count of the number of elements actually written. The mv_data
// 	of the second MDB_val is unused.
// </ul>
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>#MDB_MAP_FULL - the database is full, see `#mdb_env_set_mapsize()`.
// <li>#MDB_TXN_FULL - the transaction has too many dirty pages.
// <li>EACCES - an attempt was made to write in a read-only transaction.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_cursor_put(cursor &Mdb_cursor, key &Mdb_val, data &Mdb_val, flags u32) int {
	return C.mdb_cursor_put(cursor, key, data, flags)
}

fn C.mdb_cursor_put(cursor &Mdb_cursor, key &Mdb_val, data &Mdb_val, flags u32) int

// Delete current key/data pair
// This function deletes the key/data pair to which the cursor refers.
// This does not invalidate the cursor, so operations such as MDB_NEXT
// can still be used on it.
// Both MDB_NEXT and MDB_GET_CURRENT will return the same record after
// this operation.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
// @param[in] flags Options for this operation. This parameter
// must be set to 0 or one of the values described here.
// <ul>
// <li>#MDB_NODUPDATA - delete all of the data items for the current key.
// 	This flag may only be specified if the database was opened with #MDB_DUPSORT.
// </ul>
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EACCES - an attempt was made to write in a read-only transaction.
// <li>EINVAL - an invalid parameter was specified.
// </ul>
//
pub fn mdb_cursor_del(cursor &Mdb_cursor, flags u32) int {
	return C.mdb_cursor_del(cursor, flags)
}

fn C.mdb_cursor_del(cursor &Mdb_cursor, flags u32) int

// Return count of duplicates for current key.
// This call is only valid on databases that support sorted duplicate
// data items #MDB_DUPSORT.
// @param[in] cursor A cursor handle returned by #mdb_cursor_open()
// @param[out] countp Address where the count will be stored
// @return A non-zero error value on failure and 0 on success. Some possible
// errors are:
// <ul>
// <li>EINVAL - cursor is not initialized, or an invalid parameter was specified.
// </ul>
//
pub fn mdb_cursor_count(cursor &Mdb_cursor, countp &Mdb_size_t) int {
	return C.mdb_cursor_count(cursor, countp)
}

fn C.mdb_cursor_count(cursor &Mdb_cursor, countp &Mdb_size_t) int

// Compare two data items according to a particular database.
// This returns a comparison as if the two data items were keys in the
// specified database.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] a The first item to compare
// @param[in] b The second item to compare
// @return < 0 if a < b, 0 if a == b, > 0 if a > b
//
pub fn mdb_cmp(txn &Mdb_txn, dbi Mdb_dbi, const_a &Mdb_val, const_b &Mdb_val) int {
	return C.mdb_cmp(txn, dbi, const_a, const_b)
}

fn C.mdb_cmp(txn &Mdb_txn, dbi Mdb_dbi, const_a &Mdb_val, const_b &Mdb_val) int

// Compare two data items according to a particular database.
// This returns a comparison as if the two items were data items of
// the specified database. The database must have the #MDB_DUPSORT flag.
// @param[in] txn A transaction handle returned by #mdb_txn_begin()
// @param[in] dbi A database handle returned by #mdb_dbi_open()
// @param[in] a The first item to compare
// @param[in] b The second item to compare
// @return < 0 if a < b, 0 if a == b, > 0 if a > b
//
pub fn mdb_dcmp(txn &Mdb_txn, dbi Mdb_dbi, const_a &Mdb_val, const_b &Mdb_val) int {
	return C.mdb_dcmp(txn, dbi, const_a, const_b)
}

fn C.mdb_dcmp(txn &Mdb_txn, dbi Mdb_dbi, const_a &Mdb_val, const_b &Mdb_val) int

// A callback function used to print a message from the library.
// @param[in] msg The string to be printed.
// @param[in] ctx An arbitrary context pointer for the callback.
// @return < 0 on failure, >= 0 on success.
//
pub type MDB_msg_func = fn (const_msg &char, ctx voidptr) int

// Dump the entries in the reader lock table.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[in] func A #MDB_msg_func function
// @param[in] ctx Anything the message function needs
// @return < 0 on failure, >= 0 on success.
//
pub fn mdb_reader_list(env &Mdb_env, func MDB_msg_func, ctx voidptr) int {
	return C.mdb_reader_list(env, func, ctx)
}

fn C.mdb_reader_list(env &Mdb_env, func MDB_msg_func, ctx voidptr) int

// Check for stale entries in the reader lock table.
// @param[in] env An environment handle returned by `#mdb_env_create()`
// @param[out] dead Number of stale slots that were cleared
// @return 0 on success, non-zero on failure.
//
pub fn mdb_reader_check(env &Mdb_env, dead &int) int {
	return C.mdb_reader_check(env, dead)
}

fn C.mdb_reader_check(env &Mdb_env, dead &int) int
