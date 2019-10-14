require! <[fs]>

Util = -> @buf = it; return @
Util.prototype = do
  buf: null
  pad: -> "0" * (2 - ("#it".length <? 2)) + it
  value: (i,len = 1) ->
    for j from 0 til len => ret = (ret or 0) * 256 + @buf[i + j]
    return ret
  ascii-at: (i) -> @ascii i, 1
  ascii: (i,c) -> [String.fromCharCode(@buf[j]) for j from i til i + c].join("")
  subbuf: (i, c) ->
    ret = Buffer.allocUnsafe(c)
    @buf.slice(i, i + c).copy(ret)
    return ret
  subtil: (i, c) -> new Util @subbuf(i,c)
  data-at: (i) -> @data i, 1
  data: (i,c) -> @raw.substring(i,i + c)
  hex-at: (i) -> @hex i, 1
  hex: (i,c) ->
    [@pad(@buf[j].toString(\16).toUpperCase!) for j from i til i + c].join("")

raw = fs.read-file-sync \bar.mp4, \binary
root = new Util(Buffer.from(raw, \binary))


box = do
  #dref: (buf, hl, bl) -> { box: parse buf.subtil hl, bl }
  #stsd: (buf, hl, bl) -> { box: parse buf.subtil hl, bl }
  container: <[moov trak mdia minf dinf stbl mp4a esds]>
  ftyp: (buf, hl, bl) ->
    ret = do
      length: hl + bl
      major-brand: buf.ascii(hl, 4)
      minor-version: buf.value(hl + 4, 4)
      compatible-brands: []
    for i from hl + 8 til bl by 4 =>
      ret.compatible-brands.push buf.ascii(i, 4)
    ret
  mvhd: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      creation-time: buf.value(hl + 4, 4)
      modification-time: buf.value(hl + 8, 4)
      time-scale: buf.value(hl + 12, 4)
      duration: buf.value(hl + 16, 4)
      rate: +"#{buf.value(hl + 20, 2)}.#{buf.value(hl + 22, 2)}"
      volume: +"#{buf.value(hl + 24, 1)}.#{buf.value(hl + 25, 1)}"
      reserved: buf.subbuf(hl + 26, 10)
      matrix: buf.subbuf(hl + 36, 36)
      pre-defined: buf.subbuf(hl + 72, 24)
      next-track-id: buf.value(hl + 96, 4)
    }
  tkhd: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      creation-time: buf.value(hl + 4, 4)
      modification-time: buf.value(hl + 8, 4)
      track-id: buf.value(hl + 12, 4)
      # reserved 4
      duration: buf.value(hl + 20, 4)
      # reserved 8
      layer: buf.value(hl + 32, 2)
      alternate-group: buf.value(hl + 34, 2)
      volume: +"#{buf.value(hl + 36, 1)}.#{buf.value(hl + 37, 1)}"
      # reserved 2
      matrix: buf.subbuf(hl + 40, 36)
      width: +"#{buf.value(hl + 76, 2)}.#{buf.value(hl + 78, 2)}"
      height: +"#{buf.value(hl + 80, 2)}.#{buf.value(hl + 82, 2)}"
    }
  mdhd: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      creation-time: buf.value(hl + 4, 4)
      modification-time: buf.value(hl + 8, 4)
      time-scale: buf.value(hl + 12, 4)
      duration: buf.value(hl + 16, 4)
      language: buf.value(hl + 20, 2)
      pre-defined: buf.value(hl + 22, 2)
    }
  hdlr: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      pre-defined: buf.value(hl + 4, 4)
      handler-type: buf.ascii(hl + 8, 4)
    }
  vmhd: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      graphics-mode: buf.value(hl + 4, 4)
      opcolor: [
        buf.value(hl + 8, 2)
        buf.value(hl + 10, 2)
        buf.value(hl + 12, 2)
      ]
    }
  smhd: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      balance: buf.value(hl + 4, 2)
    }
  dref: (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      entry-count: buf.value(hl + 4, 4)
      url: parse buf.subtil(hl + 8, bl - 8)
    }
  "url ": (buf, hl, bl) ->
    return {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
    }
  stsd: (buf, hl, bl) ->
    ret = {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      entry-count: buf.value(hl + 4, 4)
      sample-descriptions: []
    }
    for idx from 0 til ret.entry-count =>
      ret.sample-descriptions.push {
        size: buf.value(hl + 8 + idx * 16, 4)
        type: buf.ascii(hl + 12 + idx * 16, 4)
        ref-index: buf.value(hl + 22 + idx * 16, 2)
      }
    return ret
  stts: (buf, hl, bl) -> # Time to Sample. TODO: parse entry
    ret = {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      entry-count: buf.value(hl + 4, 4)
    }
    return ret
  stsc: (buf, hl, bl) -> # Sample to Chunk. TODO: parse entry
    ret = {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      entry-count: buf.value(hl + 4, 4)
    }
    return ret
  stsz: (buf, hl, bl) -> #  Sample Size Box
    ret = {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      sample-size: buf.value(hl + 4, 4) # 0 if samples have different size; otherwise this is the size.
      entry-count: buf.value(hl + 8, 4)
      size: []
    }
    for idx from 0 til ret.entry-count => ret.size.push buf.value(hl + 12 + idx * 4, 4)
    return ret
  stco: (buf, hl, bl) -> # Chunk Offset Box
    ret = {
      version: buf.value(hl, 1)
      flags: buf.value(hl + 1, 3)
      entry-count: buf.value(hl + 4, 4)
      offset: [] # list of absolute offset from begining of the file.
    }
    for idx from 0 til ret.entry-count => ret.offset.push buf.value(hl + 8 + idx * 4, 4)
    return ret


/*
stbl 
  stsd ( sample description box ) 
  stts ( time to sample box )
  stsz ( sample size box )
  stsc ( sample to chunk box )
  stco ( chunk offset box ) 
  ctts ( composition time to sample )
  stss ( sync sample box )
*/


parse = (buf) ->
  idx = 0
  ret = []
  while idx < buf.buf.length
    [len, type, hlen] = [buf.value(idx, 4), buf.ascii(idx + 4, 4), 8]
    if len == 1 => [len,hlen] = [buf.value(idx + 8, 8), 16]
    console.log type
    if len <= 0 =>
      console.log ">", len, type, buf.buf.length, buf.buf
      break
    # 00 00 00 00 00 00 00 01 00 00 00 0c 75 72 6c 20 00 00 00 01
    if box[type] => ret.push(box[type](buf.subtil(idx, len), hlen, len - hlen) <<< {type})
    else if type in box.container => ret.push({ box: parse(buf.subtil idx + hlen, len - hlen) } <<< {type})
    else ret.push {type: type}
    idx += len
  return ret

ret = parse(root)
console.log JSON.stringify(ret, 1, 2)
