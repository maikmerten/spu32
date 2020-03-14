/*-----------------------------------------------------------------------*/
/* Low level disk I/O module skeleton for FatFs     (C)ChaN, 2019        */
/*-----------------------------------------------------------------------*/
/* If a working storage control module is available, it should be        */
/* attached to the FatFs via a glue function rather than modifying it.   */
/* This is an example of glue functions to attach various exsisting      */
/* storage control modules to the FatFs module with a defined API.       */
/*-----------------------------------------------------------------------*/

#include "ff.h"			/* Obtains integer types */
#include "diskio.h"		/* Declarations of disk functions */

#include "../bios_shared.h"
#include "../bios_sdcard.h"

/* Definitions of physical drive number for each drive */
#define DEV_SD		0


/*-----------------------------------------------------------------------*/
/* Get Drive Status                                                      */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status (
	BYTE pdrv		/* Physical drive nmuber to identify the drive */
)
{
	return disk_initialize(pdrv);

	//return STA_NOINIT;
}



/*-----------------------------------------------------------------------*/
/* Inidialize a Drive                                                    */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize (
	BYTE pdrv				/* Physical drive nmuber to identify the drive */
)
{
	struct request_init_block_device_t req;

   	req.command = CMD_INIT_BLOCK_DEVICE;
   	req.device = DEVICE_SD;
		
	result_t res = bios_sd_init(&req);

	if(res == RESULT_OK) {
		return 0;
	}

	return STA_NOINIT;
}



/*-----------------------------------------------------------------------*/
/* Read Sector(s)                                                        */
/*-----------------------------------------------------------------------*/

DRESULT disk_read (
	BYTE pdrv,		/* Physical drive nmuber to identify the drive */
	BYTE *buff,		/* Data buffer to store read data */
	LBA_t sector,	/* Start sector in LBA */
	UINT count		/* Number of sectors to read */
)
{

	for(uint32_t block = sector; block < (sector + count); ++block) {
		result_t res = bios_sd_read_block(block, (uint8_t*)buff);
		if(res != RESULT_OK) {
			return RES_ERROR;
		}
		buff += 512;
	}

	return RES_OK;
}



/*-----------------------------------------------------------------------*/
/* Write Sector(s)                                                       */
/*-----------------------------------------------------------------------*/

#if FF_FS_READONLY == 0

DRESULT disk_write (
	BYTE pdrv,			/* Physical drive nmuber to identify the drive */
	const BYTE *buff,	/* Data to be written */
	LBA_t sector,		/* Start sector in LBA */
	UINT count			/* Number of sectors to write */
)
{
	for(uint32_t block = sector; block < (sector + count); ++block) {
		result_t res = bios_sd_write_block(block, (uint8_t*)buff);
		if(res != RESULT_OK) {
			return RES_ERROR;
		}
		buff += 512;
	}

}

#endif


/*-----------------------------------------------------------------------*/
/* Miscellaneous Functions                                               */
/*-----------------------------------------------------------------------*/

DRESULT disk_ioctl (
	BYTE pdrv,		/* Physical drive nmuber (0..) */
	BYTE cmd,		/* Control code */
	void *buff		/* Buffer to send/receive control data */
)
{
	
	switch(cmd) {
		case CTRL_SYNC:
			return RES_OK;

		case GET_SECTOR_SIZE:
			*(WORD *) buff = 512;
			return RES_OK;
		

	}

	return RES_PARERR;
}

