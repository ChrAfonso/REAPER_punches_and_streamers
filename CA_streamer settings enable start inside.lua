GMEM_NAME = "CA_Punches_Streamers"
GMEM_START_INSIDE = 0
GMEM_END_INSIDE = 1

reaper.gmem_attach(GMEM_NAME)

reaper.gmem_write(GMEM_START_INSIDE, 1)