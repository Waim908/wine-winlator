/*
 * Wine MIDI mapper driver
 *
 * Copyright 1999, 2000, 2001 Eric Pouech
 * Copyright 2025 BrunoSX
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 *
 */

#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include "windef.h"
#include "winbase.h"
#include "wingdi.h"
#include "winuser.h"
#include "mmddk.h"
#include "winreg.h"
#include "wine/debug.h"
#include "winsock2.h"

WINE_DEFAULT_DEBUG_CHANNEL(midi);
WINE_DECLARE_DEBUG_CHANNEL(winediag);

#define MIDI_OUT_PORT 7950
#define MIDI_IN_PORT 7951
#define MIDI_OPEN_PORT 7947

#define REQUEST_CODE_MIDI_OPEN 16
#define REQUEST_CODE_MIDI_CLOSE 17

typedef struct tagMIDIINDEV
{
    BOOL running;
    HANDLE thread;
    LPMIDIOPENDESC midiDesc;
    WORD wCbFlags;
} MIDIINDEV;

typedef	struct tagMIDIOUTDEV
{
    LPMIDIOPENDESC midiDesc;
    BYTE runningStatus;
    WORD wCbFlags;
} MIDIOUTDEV;

static MIDIOUTDEV midiOutDev = {0};
static MIDIINDEV midiInDev = {0};

static SOCKET serverSock = INVALID_SOCKET;
static BOOL winsockLoaded = FALSE;

static void closeServerSocket(void)
{
    if (serverSock != INVALID_SOCKET)
    {
        closesocket(serverSock);
        serverSock = INVALID_SOCKET;
    }

    if (winsockLoaded)
    {
        WSACleanup();
        winsockLoaded = FALSE;
    }
}

static BOOL createServerSocket(void)
{
    WSADATA wsaData;
    struct sockaddr_in serverAddr;
    const UINT reuseAddr = 1;
    ULONG nonBlocking = 1;
    int res;

    closeServerSocket();

    winsockLoaded = WSAStartup(MAKEWORD(2,2), &wsaData) == NO_ERROR;
    if (!winsockLoaded) return FALSE;

    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    serverAddr.sin_port = htons(MIDI_IN_PORT);

    serverSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (serverSock == INVALID_SOCKET) return FALSE;

    res = setsockopt(serverSock, SOL_SOCKET, SO_REUSEADDR, (const char *)&reuseAddr, sizeof(reuseAddr));
    if (res == SOCKET_ERROR) return FALSE;

    ioctlsocket(serverSock, FIONBIO, &nonBlocking);

    res = bind(serverSock, (struct sockaddr*)&serverAddr, sizeof(serverAddr));
    if (res == SOCKET_ERROR) return FALSE;

    return TRUE;
}

static void midiOpenRequest(BOOL isMidiOut)
{
    char buffer[64] = {0};
    struct sockaddr_in clientAddr;

    clientAddr.sin_family = AF_INET;
    clientAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    clientAddr.sin_port = htons(MIDI_OPEN_PORT);

    buffer[0] = REQUEST_CODE_MIDI_OPEN;
    buffer[1] = isMidiOut ? 1 : 0;
    sendto(serverSock, buffer, 64, 0, (struct sockaddr*)&clientAddr, sizeof(clientAddr));
}

static void midiCloseRequest(BOOL isMidiOut)
{
    char buffer[64] = {0};
    struct sockaddr_in clientAddr;

    clientAddr.sin_family = AF_INET;
    clientAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    clientAddr.sin_port = htons(MIDI_OPEN_PORT);

    buffer[0] = REQUEST_CODE_MIDI_CLOSE;
    buffer[1] = isMidiOut ? 1 : 0;
    sendto(serverSock, buffer, 64, 0, (struct sockaddr*)&clientAddr, sizeof(clientAddr));
}

static DWORD midiSendDataMsg(DWORD_PTR dwParam)
{
    char buffer[16] = {0};
    struct sockaddr_in clientAddr;

    clientAddr.sin_family = AF_INET;
    clientAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    clientAddr.sin_port = htons(MIDI_OUT_PORT);

    buffer[0] = 1; /* SHORT DATA */
    *(DWORD_PTR*)(buffer + 1) = dwParam;

    sendto(serverSock, buffer, 16, 0, (struct sockaddr*)&clientAddr, sizeof(clientAddr));
    return MMSYSERR_NOERROR;
}

static void MIDIMAP_NotifyClient(WORD wMsg, LPMIDIOPENDESC lpDesc, WORD wCbFlags, DWORD_PTR dwParam1, DWORD_PTR dwParam2)
{
    DriverCallback(lpDesc->dwCallback, wCbFlags, (HDRVR)lpDesc->hMidi, wMsg, lpDesc->dwInstance, dwParam1, dwParam2);
}

static DWORD modOpen(LPMIDIOPENDESC lpDesc, DWORD dwFlags)
{
    if (!lpDesc)
        return MMSYSERR_INVALPARAM;

    if (midiOutDev.midiDesc)
        return MMSYSERR_ALLOCATED;

    midiOutDev.midiDesc = lpDesc;
    midiOutDev.wCbFlags = HIWORD(dwFlags & CALLBACK_TYPEMASK);
    midiOutDev.runningStatus = 0;

    midiOpenRequest(TRUE);
    MIDIMAP_NotifyClient(MOM_OPEN, midiOutDev.midiDesc, midiOutDev.wCbFlags, 0L, 0L);
    return MMSYSERR_NOERROR;
}

static DWORD modClose(void)
{
    if (!midiOutDev.midiDesc)
        return MMSYSERR_ERROR;

    midiCloseRequest(TRUE);
    MIDIMAP_NotifyClient(MOM_CLOSE, midiOutDev.midiDesc, midiOutDev.wCbFlags, 0L, 0L);
    midiOutDev.midiDesc = NULL;
    return MMSYSERR_NOERROR;
}

static DWORD modLongData(LPMIDIHDR lpMidiHdr, DWORD_PTR dwParam2)
{
    DWORD ret = MMSYSERR_NOERROR;

    if (!(lpMidiHdr->dwFlags & MHDR_PREPARED))
        return MIDIERR_UNPREPARED;

    if (lpMidiHdr->dwFlags & MHDR_INQUEUE)
        return MIDIERR_STILLPLAYING;

    FIXME("midi long data not implemented yet\n");

    midiOutDev.runningStatus = 0;
    lpMidiHdr->dwFlags &= ~MHDR_INQUEUE;
    lpMidiHdr->dwFlags |= MHDR_DONE;
    MIDIMAP_NotifyClient(MOM_DONE, midiOutDev.midiDesc, midiOutDev.wCbFlags, (DWORD_PTR)lpMidiHdr, 0L);
    return ret;
}

static DWORD modData(DWORD_PTR dwParam)
{
    BYTE status = LOBYTE(LOWORD(dwParam));
    DWORD ret = MMSYSERR_NOERROR;

    if (status < 0x80)
    {
        if (midiOutDev.runningStatus)
        {
            status = midiOutDev.runningStatus;
            dwParam = ((LOWORD(dwParam) << 8) | status);
        }
        else
        {
            FIXME("ooch %Ix\n", dwParam);
            return MMSYSERR_NOERROR;
        }
    }

    ret = midiSendDataMsg(dwParam);

    /* system common message */
    if (status <= 0xF7)
        midiOutDev.runningStatus = 0;

    return ret;
}

static DWORD modPrepare(LPMIDIHDR lpMidiHdr, DWORD_PTR dwSize)
{
    if (dwSize < offsetof(MIDIHDR,dwOffset) || lpMidiHdr == 0 || lpMidiHdr->lpData == 0)
        return MMSYSERR_INVALPARAM;

    if (lpMidiHdr->dwFlags & MHDR_PREPARED)
        return MMSYSERR_NOERROR;

    lpMidiHdr->dwFlags |= MHDR_PREPARED;
    lpMidiHdr->dwFlags &= ~(MHDR_DONE | MHDR_INQUEUE); /* flags cleared since w2k */
    return MMSYSERR_NOERROR;
}

static DWORD modUnprepare(LPMIDIHDR lpMidiHdr, DWORD_PTR dwSize)
{
    if (dwSize < offsetof(MIDIHDR,dwOffset) || lpMidiHdr == 0 || lpMidiHdr->lpData == 0)
        return MMSYSERR_INVALPARAM;

    if (!(lpMidiHdr->dwFlags & MHDR_PREPARED))
        return MMSYSERR_NOERROR;

    if (lpMidiHdr->dwFlags & MHDR_INQUEUE)
        return MIDIERR_STILLPLAYING;

    lpMidiHdr->dwFlags &= ~MHDR_PREPARED;
    return MMSYSERR_NOERROR;
}

static DWORD modGetVolume(DWORD* lpdwVolume)
{
    if (!lpdwVolume) return MMSYSERR_INVALPARAM;
    *lpdwVolume = 0xFFFFFFFF; /* tests show this initial value */
    return MMSYSERR_NOERROR;
}

static DWORD modSetVolume(DWORD dwVolume)
{
    /* Native forwards it to some underlying device
     * GetVolume returns what was last set here. */
    FIXME("stub\n");
    return MMSYSERR_NOERROR;
}

static DWORD modGetDevCaps(LPMIDIOUTCAPSW lpCaps, DWORD_PTR size)
{
    static const MIDIOUTCAPSW tmpCaps = {
        0x00FF, 0x0001, 0x0100, /* Manufacturer and Product ID */
        L"Wine Midi-Out", MOD_MAPPER, 0, 0, 0xFFFF,
        MIDICAPS_VOLUME|MIDICAPS_LRVOLUME /* Native returns volume caps of underlying device + MIDICAPS_STREAM */
    };

    if (!lpCaps)
        return MMSYSERR_INVALPARAM;

    memcpy(lpCaps, &tmpCaps, min(size, sizeof(*lpCaps)));
    return MMSYSERR_NOERROR;
}

static DWORD modReset(void)
{
    midiOutDev.runningStatus = 0;
    return MMSYSERR_NOERROR;
}

static DWORD WINAPI MidThreadProc(void *param)
{
    int res;
    char buffer[8];

    while (midiInDev.running)
    {
        res = recvfrom(serverSock, buffer, 8, 0, NULL, NULL);
        if (res <= 0)
        {
            if (WSAGetLastError() != WSAEWOULDBLOCK) break;
            Sleep(16);
            continue;
        }

        MIDIMAP_NotifyClient(MIM_DATA, midiInDev.midiDesc, midiInDev.wCbFlags, *(DWORD*)(buffer), 0L);
    }

    return 0;
}

static DWORD midGetDevCaps(LPMIDIINCAPSW lpCaps, DWORD_PTR size)
{
    static const MIDIINCAPSW tmpCaps = {
        0x00FF, 0x0001, 0x0100,
        L"Wine Midi-In",
        MIDICAPS_VOLUME|MIDICAPS_LRVOLUME
    };

    if (!lpCaps)
        return MMSYSERR_INVALPARAM;

    memcpy(lpCaps, &tmpCaps, min(size, sizeof(*lpCaps)));
    return MMSYSERR_NOERROR;
}

static DWORD midOpen(LPMIDIOPENDESC lpDesc, DWORD dwFlags)
{
    if (!lpDesc)
        return MMSYSERR_INVALPARAM;

    if (midiInDev.midiDesc)
        return MMSYSERR_ALLOCATED;

    midiInDev.running = TRUE;

	midiInDev.thread = CreateThread(NULL, 0, MidThreadProc, NULL, 0, NULL);
	if (!midiInDev.thread)
    {
        midiInDev.running = FALSE;
	    WARN("Failed to create thread for midi-in\n");
	    return MMSYSERR_ERROR;
	}

    midiInDev.midiDesc = lpDesc;
    midiInDev.wCbFlags = HIWORD(dwFlags & CALLBACK_TYPEMASK);

    midiOpenRequest(FALSE);
    MIDIMAP_NotifyClient(MIM_OPEN, midiInDev.midiDesc, midiInDev.wCbFlags, 0L, 0L);
    return MMSYSERR_NOERROR;
}

static DWORD midClose(void)
{
    if (!midiInDev.midiDesc)
        return MMSYSERR_ERROR;

    midiInDev.running = FALSE;
    if (midiInDev.thread)
    {
        WaitForSingleObject(midiInDev.thread, INFINITE);
        midiInDev.thread = NULL;
    }

    midiCloseRequest(FALSE);
    MIDIMAP_NotifyClient(MIM_CLOSE, midiInDev.midiDesc, midiInDev.wCbFlags, 0L, 0L);
    midiInDev.midiDesc = NULL;
    return MMSYSERR_NOERROR;
}

static DWORD midStart(void)
{
    FIXME("stub\n");
    return MMSYSERR_NOERROR;
}

static DWORD midStop(void)
{
    FIXME("stub\n");
    return MMSYSERR_NOERROR;
}

static DWORD midPrepare(LPMIDIHDR lpMidiHdr, DWORD dwSize)
{
    if (dwSize < offsetof(MIDIHDR,dwOffset) || !lpMidiHdr || lpMidiHdr->lpData == 0)
        return MMSYSERR_INVALPARAM;

    if (lpMidiHdr->dwFlags & MHDR_PREPARED)
        return MMSYSERR_NOERROR;

    lpMidiHdr->dwFlags |= MHDR_PREPARED;
    return MMSYSERR_NOERROR;
}

static DWORD midUnprepare(LPMIDIHDR lpMidiHdr, DWORD dwSize)
{
    if (dwSize < offsetof(MIDIHDR,dwOffset) || !lpMidiHdr || lpMidiHdr->lpData == 0)
        return MMSYSERR_INVALPARAM;

    if (!(lpMidiHdr->dwFlags & MHDR_PREPARED))
        return MMSYSERR_NOERROR;

    if (lpMidiHdr->dwFlags & MHDR_INQUEUE)
        return MIDIERR_STILLPLAYING;

    lpMidiHdr->dwFlags &= ~MHDR_PREPARED;
    return MMSYSERR_NOERROR;
}

static DWORD midAddBuffer(LPMIDIHDR lpMidiHdr, DWORD dwSize)
{
    if (dwSize < offsetof(MIDIHDR,dwOffset) || !lpMidiHdr || lpMidiHdr->lpData == 0)
        return MMSYSERR_INVALPARAM;

    if (!(lpMidiHdr->dwFlags & MHDR_PREPARED))
        return MMSYSERR_NOERROR;

    if (lpMidiHdr->dwFlags & MHDR_INQUEUE)
        return MIDIERR_STILLPLAYING;

    FIXME("stub\n");
    return MMSYSERR_NOERROR;
}

static DWORD midReset(void)
{
    FIXME("stub\n");
    return MMSYSERR_NOERROR;
}

static LRESULT MIDIMAP_drvOpen(void);
static LRESULT MIDIMAP_drvClose(void);

/**************************************************************************
 * 				modMessage (MIDIMAP.@)
 */
DWORD WINAPI MIDIMAP_modMessage(UINT wDevID, UINT wMsg, DWORD_PTR dwUser,
                                DWORD_PTR dwParam1, DWORD_PTR dwParam2)
{
    TRACE("(%u, %04X, %08IX, %08IX, %08IX);\n", wDevID, wMsg, dwUser, dwParam1, dwParam2);

    switch (wMsg)
    {
        case DRVM_INIT: return MIDIMAP_drvOpen();
        case DRVM_EXIT: return MIDIMAP_drvClose();
        case DRVM_ENABLE:
        case DRVM_DISABLE:
            /* FIXME: Pretend this is supported */
            return 0;

        case MODM_OPEN: return modOpen((LPMIDIOPENDESC)dwParam1, dwParam2);
        case MODM_CLOSE: return modClose();

        case MODM_DATA: return modData(dwParam1);
        case MODM_LONGDATA:	return modLongData((LPMIDIHDR)dwParam1, dwParam2);
        case MODM_PREPARE: return modPrepare((LPMIDIHDR)dwParam1, dwParam2);
        case MODM_UNPREPARE: return modUnprepare((LPMIDIHDR)dwParam1, dwParam2);
        case MODM_RESET: return modReset();

        case MODM_GETDEVCAPS: return modGetDevCaps((LPMIDIOUTCAPSW)dwParam1, dwParam2);
        case MODM_GETNUMDEVS: return 1;
        case MODM_GETVOLUME: return modGetVolume((DWORD*)dwParam1);
        case MODM_SETVOLUME: return modSetVolume(dwParam1);
        default:
            FIXME("unknown message %d!\n", wMsg);
    }
    return MMSYSERR_NOTSUPPORTED;
}

/**************************************************************************
 * 				midMessage (MIDIMAP.@)
 */
DWORD WINAPI MIDIMAP_midMessage(UINT wDevID, UINT wMsg, DWORD_PTR dwUser,
                                DWORD_PTR dwParam1, DWORD_PTR dwParam2)
                                {
    TRACE("(%u, %04X, %08IX, %08IX, %08IX);\n", wDevID, wMsg, dwUser, dwParam1, dwParam2);

    switch (wMsg)
    {
        case DRVM_INIT: return MIDIMAP_drvOpen();
        case DRVM_EXIT: return MIDIMAP_drvClose();
        case DRVM_ENABLE:
        case DRVM_DISABLE:
            /* FIXME: Pretend this is supported */
            return 0;
        case MIDM_OPEN: return midOpen((LPMIDIOPENDESC)dwParam1, dwParam2);
        case MIDM_CLOSE: return midClose();

        case MIDM_START: return midStart();
        case MIDM_STOP: return midStop();
        case MIDM_PREPARE: return midPrepare((LPMIDIHDR)dwParam1, dwParam2);
        case MIDM_UNPREPARE: return midUnprepare((LPMIDIHDR)dwParam1, dwParam2);
        case MIDM_ADDBUFFER: return midAddBuffer((LPMIDIHDR)dwParam1, dwParam2);
        case MIDM_RESET: return midReset();

        case MIDM_GETDEVCAPS: return midGetDevCaps((LPMIDIINCAPSW)dwParam1, dwParam2);
        case MIDM_GETNUMDEVS: return 1;
        default:
            FIXME("unknown message %d!\n", wMsg);
    }
    return MMSYSERR_NOTSUPPORTED;
}

/*======================================================================*
 *                  Driver part                                         *
 *======================================================================*/

/**************************************************************************
 * 				MIDIMAP_drvOpen			[internal]
 */
static LRESULT MIDIMAP_drvOpen(void)
{
    createServerSocket();
    return MMSYSERR_NOERROR;
}

/**************************************************************************
 * 				MIDIMAP_drvClose		[internal]
 */
static LRESULT MIDIMAP_drvClose(void)
{
    closeServerSocket();
    return MMSYSERR_NOERROR;
}

/**************************************************************************
 * 				DriverProc (MIDIMAP.@)
 */
LRESULT CALLBACK MIDIMAP_DriverProc(DWORD_PTR dwDevID, HDRVR hDriv, UINT wMsg,
                                    LPARAM dwParam1, LPARAM dwParam2)
{
    /*
    TRACE("(%08lX, %04X, %08lX, %08lX, %08lX)\n",
        dwDevID, hDriv, wMsg, dwParam1, dwParam2);
    */

    switch (wMsg)
    {
        case DRV_LOAD: return 1;
        case DRV_FREE: return 1;
        case DRV_OPEN: return 1;
        case DRV_CLOSE:	return 1;
        case DRV_ENABLE: return 1;
        case DRV_DISABLE: return 1;
        case DRV_QUERYCONFIGURE: return 1;
        case DRV_CONFIGURE:	MessageBoxA(0, "MIDIMAP MultiMedia Driver!", "OSS Driver", MB_OK);	return 1;
        case DRV_INSTALL: return DRVCNF_RESTART;
        case DRV_REMOVE: return DRVCNF_RESTART;
        default:
            return DefDriverProc(dwDevID, hDriv, wMsg, dwParam1, dwParam2);
    }
}
