
from datetime import datetime

def get_elapsed_time(time_start):
    time_end = datetime.now()
    time_diff = time_end - time_start
    return time_diff.seconds + 1e-6 * time_diff.microseconds

