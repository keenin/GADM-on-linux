// powershell.exe stand-in for Wine: handles "Start-Process -FilePath X" by launching X,
// forwards everything else to Wine's original powershell (powershell-wine.exe).
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>
#include <stdio.h>

static void logw(const wchar_t *msg) {
    wchar_t p[MAX_PATH]; DWORD n = GetTempPathW(MAX_PATH, p);
    if (!n) return; wcscat(p, L"powershell-shim.log");
    FILE *f = _wfopen(p, L"a, ccs=UTF-8"); if (!f) return;
    SYSTEMTIME t; GetLocalTime(&t);
    fwprintf(f, L"%04d-%02d-%02d %02d:%02d:%02d %ls\n", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, msg);
    fclose(f);
}
static void strip(wchar_t *s) {
    size_t n = wcslen(s);
    while (n && (s[n-1] == L'"' || s[n-1] == L'\'' || s[n-1] == L' ')) s[--n] = 0;
    size_t i = 0; while (s[i] == L'"' || s[i] == L'\'' || s[i] == L' ') i++;
    if (i) memmove(s, s + i, (wcslen(s + i) + 1) * sizeof(wchar_t));
}
int wmain(void) {
    LPWSTR cl = GetCommandLineW();
    int argc; LPWSTR *argv = CommandLineToArgvW(cl, &argc);
    wchar_t buf[4096];
    _snwprintf(buf, 4096, L"called: %ls", cl); logw(buf);
    int sp = -1;
    for (int i = 1; i < argc; i++) if (!_wcsicmp(argv[i], L"Start-Process")) { sp = i; break; }
    if (sp > 0) {
        wchar_t file[MAX_PATH * 2] = L""; wchar_t args[4096] = L"";
        for (int i = sp + 1; i < argc; i++) {
            if (!_wcsicmp(argv[i], L"-FilePath") && i + 1 < argc) { wcsncpy(file, argv[++i], MAX_PATH*2-1); }
            else if (!_wcsicmp(argv[i], L"-ArgumentList") && i + 1 < argc) { wcsncpy(args, argv[++i], 4095); }
            else if (!_wcsicmp(argv[i], L"-Verb") && i + 1 < argc) { i++; }
            else if (argv[i][0] != L'-' && !file[0]) { wcsncpy(file, argv[i], MAX_PATH*2-1); }
        }
        strip(file); strip(args);
        if (file[0]) {
            SHELLEXECUTEINFOW sei = { sizeof(sei) };
            sei.fMask = SEE_MASK_NOASYNC; sei.lpVerb = L"open"; sei.lpFile = file;
            sei.lpParameters = args[0] ? args : NULL; sei.nShow = SW_SHOWNORMAL;
            BOOL ok = ShellExecuteExW(&sei);
            _snwprintf(buf, 4096, L"Start-Process %ls -> %ls (err %lu)", file, ok ? L"launched" : L"FAILED", ok ? 0 : GetLastError()); logw(buf);
            return ok ? 0 : 1;
        }
    }
    // forward to Wine's original
    wchar_t self[MAX_PATH]; GetModuleFileNameW(NULL, self, MAX_PATH);
    wchar_t *slash = wcsrchr(self, L'\\'); if (slash) slash[1] = 0;
    wchar_t *rest = cl;
    if (*rest == L'"') { rest++; while (*rest && *rest != L'"') rest++; if (*rest) rest++; }
    else { while (*rest && *rest != L' ' && *rest != L'\t') rest++; }
    static wchar_t fwd[32768];
    _snwprintf(fwd, 32768, L"\"%lspowershell-wine.exe\"%ls", self, rest);
    STARTUPINFOW si = { sizeof(si) }; PROCESS_INFORMATION pi;
    if (!CreateProcessW(NULL, fwd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) { logw(L"forward failed"); return 1; }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1; GetExitCodeProcess(pi.hProcess, &code);
    return (int)code;
}
