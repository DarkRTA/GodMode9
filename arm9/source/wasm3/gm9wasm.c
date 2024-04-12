#include "gm9wasm.h"
#include "stdlib.h"
#include "vff.h"
#include "ui.h"
#include "wasm3.h"

#define WASM_MOD_MAX_SIZE 0x100000

m3ApiRawFunction(gm9_print) {
	// TODO: copy instead of directly reading
	m3ApiGetArgMem(char *, string_ptr);
	ShowPrompt(false, "%s", string_ptr);
	m3ApiSuccess();
}

bool ExecuteWasmModule(const char *loadpath) {
	bool result = false;
	FIL f;

	size_t size = fvx_qsize(loadpath);
	if (!(size > 0 && size <= WASM_MOD_MAX_SIZE)) {
		ShowPrompt(false, "Invalid Module Size: %d", size);
		return false;
	}

	char *buf = malloc(size);

	if (fvx_open(&f, loadpath, (FA_READ | FA_OPEN_EXISTING) != FR_OK)) {
		ShowPrompt(false, "Failed to open module");
		goto err_free_buf;
	}

	UINT bytes_read = 0;

	if (fvx_read(&f, buf, size, &bytes_read) != FR_OK) {
		ShowPrompt(false, "Failed to read module");
		goto err_close_file;
	}

	if (bytes_read != size) {
		ShowPrompt(false, "Bytes read does not match size of module");
		goto err_close_file;
	}

	IM3Environment env = m3_NewEnvironment();
	if (!env) {
		ShowPrompt(false, "Failed to create env");
		goto err_close_file;
	}

	IM3Runtime rt = m3_NewRuntime(env, 1024 * 32, NULL);
	if (!rt) {
		ShowPrompt(false, "Failed to create rt");
		goto err_free_env;
	}

	IM3Module mod;
	if (m3_ParseModule(env, &mod, buf, size)) {
		ShowPrompt(false, "Failed to parse module");
		goto err_free_rt;
	}

	if (m3_LoadModule(rt, mod)) {
		ShowPrompt(false, "Failed to load module");
		m3_FreeModule(mod);
		goto err_free_rt;
	}

	m3_LinkRawFunction(mod, "env", "gm9_print", "v(*)", gm9_print);

	IM3Function fn;
	if (m3_FindFunction(&fn, rt, "entry")) {
		ShowPrompt(false, "Failed to find entrypoint");
		goto err_free_rt;
	};

	m3_CallV(fn);
	result = true;

err_free_rt:
	m3_FreeRuntime(rt);
err_free_env:
	m3_FreeEnvironment(env);
err_close_file:
	fvx_close(&f);
err_free_buf:
	free(buf);
	return result;
}
