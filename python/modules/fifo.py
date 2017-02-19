
import numpy
import threading

class FIFOTester(object):
    def __init__(self, backend):
        self.backend = backend
        self.chunk_size = (1 << 14)
        #   self.chunk_size = 512
    
    def run(self, N, tol=0):
        self.write_data = numpy.random.randint(0, 256, N).astype(numpy.uint8)
        #self.write_data = numpy.arange(N).astype(numpy.uint8)
        self.read_data = None
        
        def run_write():
            bytes_written = 0
            while bytes_written < N:
                chunk = self.write_data[bytes_written:bytes_written+self.chunk_size]
                this_chunk_size = chunk.shape[0]
                self.backend.write(chunk)
                bytes_written += this_chunk_size
            """
            #   Flush by writing zeros?
            for i in range(4):
                self.backend.write(numpy.ones((self.chunk_size,), dtype=numpy.uint8))
            """
        def run_read():
            #   self.backend.read(2)
            bytes_read = 0
            results = ''
            while bytes_read < N - tol:
                bytes_to_get = min(N - bytes_read, self.chunk_size)
                #   print 'Trying to get %d bytes' % bytes_to_get
                read_chunk = self.backend.read(bytes_to_get)
                #   print 'Got %d/%d bytes' % (len(read_chunk), bytes_to_get)
                #   print numpy.fromstring(read_chunk, dtype=numpy.uint8)
                if len(read_chunk) == 0:
                    time.sleep(0.1)
                results += read_chunk
                bytes_read += len(read_chunk)
            self.read_data = numpy.fromstring(results, dtype=numpy.uint8)

        write_thread = threading.Thread(target=run_write)
        read_thread = threading.Thread(target=run_read)
        
        time_start = datetime.now()
        write_thread.start()
        read_thread.start()
        
        write_thread.join(10.0)
        read_thread.join(10.0)
        time_elapsed = get_elapsed_time(time_start)
        
        #   Compare results
        if self.read_data is None:
            print 'Failed, received no data'
        elif len(self.read_data) < len(self.write_data) - tol:
            print 'Failed, received %d/%d bytes' % (len(self.read_data), len(self.write_data))
        else:
            #   If tol > 0, cut off end of write data
            self.write_data = self.write_data[:self.read_data.shape[0]]
            N_actual = self.write_data.shape[0]
            num_errors = numpy.sum(self.write_data != self.read_data)
            print 'Found %d errors in total of %d bytes' % (num_errors, N_actual)
            if num_errors == 0:
                data_rate = N / time_elapsed
                print 'Transferred %d bytes in %.3f sec (%.2f MB/s)' % (N_actual, time_elapsed, data_rate / 1e6)
            else:
                print 'Data sent:'
                print self.write_data
                print 'Data received:'
                print self.read_data
                pdb.set_trace()
