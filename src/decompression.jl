# Decompression Codec
# ===================

struct XzDecompression <: TranscodingStreams.Codec
    stream::LZMAStream
    memlimit::Integer
    flags::UInt32
end

const DEFAULT_MEM_LIMIT = 128 * 2^20

"""
    XzDecompression(;memlimit=$(DEFAULT_MEM_LIMIT))

Create an xz decompression codec.
"""
function XzDecompression(;memlimit::Integer=DEFAULT_MEM_LIMIT)
    if memlimit ≤ 0
        throw(ArgumentError("memlimit must be positive"))
    end
    return XzDecompression(LZMAStream(), memlimit, LZMA_CONCATENATED)
end

const XzDecompressionStream{S} = TranscodingStream{XzDecompression,S}

"""
    XzDecompressionStream(stream::IO)

Create an xz decompression stream.
"""
function XzDecompressionStream(stream::IO)
    return TranscodingStream(XzDecompression(), stream)
end


# Methods
# -------

function TranscodingStreams.initialize(codec::XzDecompression)
    ret = stream_decoder(codec.stream, codec.memlimit, codec.flags)
    if ret != LZMA_OK
        lzmaerror(codec.stream, ret)
    end
    finalizer(codec.stream, free)
    return
end

function TranscodingStreams.finalize(codec::XzDecompression)
    free(codec.stream)
end

function TranscodingStreams.process(codec::XzDecompression, input::Memory, output::Memory)
    stream = codec.stream
    stream.next_in = input.ptr
    stream.avail_in = input.size
    stream.next_out = output.ptr
    stream.avail_out = output.size
    if codec.flags & LZMA_CONCATENATED != 0
        action = stream.avail_in > 0 ? LZMA_RUN : LZMA_FINISH
    else
        action = LZMA_RUN
    end
    ret = code(stream, action)
    Δin = Int(input.size - stream.avail_in)
    Δout = Int(output.size - stream.avail_out)
    if ret == LZMA_OK
        return Δin, Δout, :ok
    elseif ret == LZMA_STREAM_END
        return Δin, Δout, :end
    else
        lzmaerror(stream, ret)
    end
end
