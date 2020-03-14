#include "bios_fatfs.h"
#include "fatfs/ff.h"
#include <stdint.h>

#define FILEHANDLES 4

// FatFS data structures
FATFS fatfs;

FIL file[FILEHANDLES];
uint8_t handle_used[FILEHANDLES];

DIR dir;

#define FATPTR ((FATFS*)(&fatfs))

result_t bios_fatfs_init()
{
    FRESULT res = f_mount(FATPTR, "", 1);

    if (res == FR_OK) {
        for (uint32_t i = 0; i < FILEHANDLES; ++i) {
            handle_used[i] = 0;
        }

        return RESULT_OK;
    }

    // printf("f_mount error: res = %d\n\r", res);
    return RESULT_ERR;
}

filehandle_t find_free_filehandle()
{
    for (filehandle_t fh = 0; fh < FILEHANDLES; ++fh) {
        if (!handle_used[fh]) {
            return fh;
        }
    }
    return -1;
}

result_t check_filehandle(filehandle_t fh)
{
    if (fh < 0 || fh >= FILEHANDLES) {
        return RESULT_ERRPARAMS;
    }

    if (!handle_used[fh]) {
        return RESULT_ERR;
    }

    return RESULT_OK;
}

result_t bios_fatfs_open(filehandle_t* filehandle, char* path, filemode_t mode)
{
    filehandle_t fh = find_free_filehandle();
    if (fh < 0) {
        return RESULT_TOOMANY;
    }

    int32_t res = f_open(&file[fh], path, mode);
    if (res != FR_OK) {
        return RESULT_ERR;
    }

    handle_used[fh] = 1;
    *filehandle = fh;

    return RESULT_OK;
}

result_t bios_fatfs_close(filehandle_t fh)
{
    result_t fhcheck = check_filehandle(fh);
    if (fhcheck != RESULT_OK) {
        return RESULT_ERRPARAMS;
    }

    int32_t res = f_close(&file[fh]);
    if (res != FR_OK) {
        return RESULT_ERR;
    }

    handle_used[fh] = 0;
    return RESULT_OK;
}

result_t bios_fatfs_read(filehandle_t fh, void* buf, uint32_t nbytes,
    uint32_t* readbytes)
{
    result_t fhcheck = check_filehandle(fh);
    if (fhcheck != RESULT_OK) {
        return RESULT_ERRPARAMS;
    }

    UINT bread;

    FRESULT res = f_read(&file[fh], buf, nbytes, &bread);
    *readbytes = bread;

    if (res != FR_OK) {
        return RESULT_ERR;
    }

    return RESULT_OK;
}

result_t bios_fatfs_write(filehandle_t fh, void* buf, uint32_t nbytes,
    uint32_t* writtenbytes)
{
    result_t fhcheck = check_filehandle(fh);
    if (fhcheck != RESULT_OK) {
        return RESULT_ERRPARAMS;
    }

    UINT bwritten;

    FRESULT res = f_write(&file[fh], buf, nbytes, &bwritten);
    *writtenbytes = bwritten;

    if (res != 0) {
        return RESULT_ERR;
    }

    return RESULT_OK;
}

result_t bios_fatfs_unlink(char* path)
{
    FRESULT res = f_unlink(path);
    if (res != FR_OK) {
        switch (res) {
        case FR_DENIED:
            return RESULT_DENIED;
        case FR_NO_FILE:
        case FR_NO_PATH:
            return RESULT_NOTFOUND;
        default:
            return RESULT_ERR;
        }
    }
    return RESULT_OK;
}

void copy_fileinfo(struct file_info_t* dest, FILINFO* fileinfo)
{
    dest->attrib = fileinfo->fattrib;
    dest->size = fileinfo->fsize;
    dest->date = fileinfo->fdate;
    dest->time = fileinfo->ftime;
    for (uint32_t i = 0; i < 13; ++i) {
        dest->name[i] = fileinfo->fname[i];
    }
}

result_t bios_fatfs_findfirst(char* path, char* pattern, struct file_info_t* finfo)
{
    // ensure directory is closed first
    f_closedir(&dir);

    // f_findfirst opens directory as needed
    FILINFO fileinfo;
    FRESULT res = f_findfirst(&dir, &fileinfo, path, pattern);
    if (res != FR_OK) {
        return RESULT_ERR;
    }
    copy_fileinfo(finfo, &fileinfo);

    return RESULT_OK;
}

result_t bios_fatfs_findnext(struct file_info_t* finfo)
{
    FILINFO fileinfo;
    FRESULT res = f_findnext(&dir, &fileinfo);
    if (res != FR_OK) {
        return RESULT_ERR;
    }

    copy_fileinfo(finfo, &fileinfo);
    return RESULT_OK;
}

result_t bios_fatfs_getcwd(char* buf, uint32_t len)
{
    FRESULT res = f_getcwd(buf, len);
}

result_t bios_fatfs_chdir(char* path)
{
    FRESULT res = f_chdir(path);
    if (res != FR_OK) {
        switch (res) {
        case FR_INVALID_NAME:
        case FR_INVALID_DRIVE:
            return RESULT_INVALID;
        default:
            return RESULT_ERR;
        }
    }
    return RESULT_OK;
}

result_t bios_fatfs_free(uint64_t* free)
{
    FATFS* fsptr;
    DWORD freeclusters;
    FRESULT res = f_getfree("", &freeclusters, &fsptr);
    if (res != FR_OK) {
        return RESULT_ERR;
    }

    uint32_t clustersize = fsptr->csize * 512;
    *free = ((uint64_t)clustersize) * ((uint64_t)freeclusters);

    return RESULT_OK;
}

result_t bios_fatfs_seek(filehandle_t fh, uint32_t position)
{
    result_t fhcheck = check_filehandle(fh);
    if (fhcheck != RESULT_OK) {
        return RESULT_ERRPARAMS;
    }

    DWORD pos = (DWORD)position;
    FRESULT res = f_lseek(&file[fh], pos);
    if (res != FR_OK) {
        return RESULT_ERR;
    }

    return RESULT_OK;
}

result_t bios_fatfs_mkdir(char* path)
{
    FRESULT res = f_mkdir(path);
    if (res != FR_OK) {
        return RESULT_ERR;
    }
    return RESULT_OK;
}

result_t bios_fatfs_rename(char* oldname, char* newname)
{
    FRESULT res = f_rename(oldname, newname);
    if (res != FR_OK) {
        return RESULT_ERR;
    }
    return RESULT_OK;
}

result_t bios_fatfs_size(filehandle_t fh, uint32_t* size)
{
    result_t fhcheck = check_filehandle(fh);
    if (fhcheck != RESULT_OK) {
        return RESULT_ERRPARAMS;
    }

    FIL f = file[fh];
    *size = (uint32_t)f.obj.objsize;
    return RESULT_OK;
}

result_t bios_fatfs_tell(filehandle_t fh, uint32_t* position) {
    result_t fhcheck = check_filehandle(fh);
    if (fhcheck != RESULT_OK) {
        return RESULT_ERRPARAMS;
    }

    *position = (uint32_t) f_tell(&file[fh]);
    return RESULT_OK;
}


result_t bios_fatfs_stat(char* path, struct file_info_t* finfo) {
    FILINFO fileinfo;
    FRESULT res = f_stat(path, &fileinfo);
    if(res != FR_OK) {
        return RESULT_ERR;
    }

    copy_fileinfo(finfo, &fileinfo);
    return RESULT_OK;
}
