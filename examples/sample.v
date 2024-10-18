// this sample was mostly generated via `v translate ./thirdparty/sample-mdb.c`

module main

import vlmdb
fn main() {
	mut rc := 0
	env := &vlmdb.Mdb_env(unsafe { nil })
	mut dbi := u32(0)
	mut key := vlmdb.Mdb_val{}
	mut data := vlmdb.Mdb_val{}

	txn := &vlmdb.Mdb_txn(unsafe { nil })
	cursor := &vlmdb.Mdb_cursor(unsafe { nil })
	sval := [32]i8{}

	println('LMDB tutorial')

	rc = vlmdb.mdb_env_create(&env)
	if rc != 0 {
		println('Error creating environment')
		unsafe {
			goto leave
		} // id: 0x1458af148
	}
	rc = vlmdb.mdb_env_open(env, c'./testdb', 0, u16(664))
	if rc != 0 {
		println('Error opening environment')
		err := vlmdb.mdb_strerror(rc)
		unsafe {
			err_str := cstring_to_vstring(err)
			if err_str.contains('Permission denied') {
				println('Permission denied. Try running as root, or creating ./testdb manually')
				goto leave
			}
			println(err_str)
			goto leave
		} // id: 0x1458af148
	}
	rc = vlmdb.mdb_txn_begin(env, (unsafe { nil }), 0, &txn)
	if rc != 0 {
		println('Error starting transaction')
		unsafe {
			goto leave
		} // id: 0x1458af148
	}
	rc = vlmdb.mdb_dbi_open(txn, (unsafe { nil }), 0, &dbi)
	if rc != 0 {
		println('Error opening dbi')
		unsafe {
			goto leave
		} // id: 0x1458af148
	}
	key.mv_size = sizeof(int)
	unsafe {
		key.mv_data = &sval[0]
	}
	data.mv_size = sizeof(sval)
	unsafe {
		data.mv_data = &sval[0]
	}
	rc = vlmdb.mdb_put(txn, dbi, &key, &data, 0)
	rc = vlmdb.mdb_txn_commit(txn)
	if rc != 0 {
		println('Error putting data')
		unsafe {
			goto leave
		} // id: 0x1458af148
	}
	rc = vlmdb.mdb_txn_begin(env, (unsafe { nil }), 131072, &txn)
	rc = vlmdb.mdb_cursor_open(txn, dbi, &cursor)
	for {
		rc = vlmdb.mdb_cursor_get(cursor, &key, &data, vlmdb.Mdb_cursor_op.mdb_next)
		if rc != 0 {
			break
		}
		C.printf(c'key: %p %.*s, data: %p %.*s\n', key.mv_data, int(key.mv_size), &i8(key.mv_data),
			data.mv_data, int(data.mv_size), &i8(data.mv_data))
	}
	vlmdb.mdb_cursor_close(cursor)
	vlmdb.mdb_txn_abort(txn)

	leave:
	vlmdb.mdb_dbi_close(env, dbi)
	vlmdb.mdb_env_close(env)
	return
}
