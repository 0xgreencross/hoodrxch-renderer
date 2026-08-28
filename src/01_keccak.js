// ---------------------------------------------------------------------------
// keccak256 (Ethereum variant, pad 0x01..0x80). BigInt lanes. Input: Uint8Array.
// ---------------------------------------------------------------------------
const KECCAK_RC = [
  0x0000000000000001n,0x0000000000008082n,0x800000000000808an,0x8000000080008000n,
  0x000000000000808bn,0x0000000080000001n,0x8000000080008081n,0x8000000000008009n,
  0x000000000000008an,0x0000000000000088n,0x0000000080008009n,0x000000008000000an,
  0x000000008000808bn,0x800000000000008bn,0x8000000000008089n,0x8000000000008003n,
  0x8000000000008002n,0x8000000000000080n,0x000000000000800an,0x800000008000000an,
  0x8000000080008081n,0x8000000000008080n,0x0000000080000001n,0x8000000080008008n];
const KECCAK_ROT = [[0,36,3,41,18],[1,44,10,45,2],[62,6,43,15,61],[28,55,25,21,56],[27,20,39,8,14]];
const M64 = (1n<<64n)-1n;
function rotl64(x,n){ n=BigInt(n); return n===0n?x:(((x<<n)|(x>>(64n-n)))&M64); }
function keccakF(A){
  for(let r=0;r<24;r++){
    const C=[0n,0n,0n,0n,0n];
    for(let x=0;x<5;x++) C[x]=A[x]^A[x+5]^A[x+10]^A[x+15]^A[x+20];
    for(let x=0;x<5;x++){ const D=C[(x+4)%5]^rotl64(C[(x+1)%5],1); for(let y=0;y<25;y+=5) A[x+y]^=D; }
    const B=new Array(25);
    for(let x=0;x<5;x++) for(let y=0;y<5;y++) B[y+5*((2*x+3*y)%5)]=rotl64(A[x+5*y],KECCAK_ROT[x][y]);
    for(let x=0;x<5;x++) for(let y=0;y<5;y++) A[x+5*y]=B[x+5*y]^((~B[(x+1)%5+5*y]&M64)&B[(x+2)%5+5*y]);
    A[0]^=KECCAK_RC[r];
  }
}
function keccak256(bytes){
  const rate=136, A=new Array(25).fill(0n);
  const padded=new Uint8Array(Math.ceil((bytes.length+1)/rate)*rate);
  padded.set(bytes); padded[bytes.length]^=0x01; padded[padded.length-1]^=0x80;
  for(let off=0;off<padded.length;off+=rate){
    for(let i=0;i<17;i++){ let v=0n; for(let b=7;b>=0;b--) v=(v<<8n)|BigInt(padded[off+i*8+b]); A[i]^=v; }
    keccakF(A);
  }
  const out=new Uint8Array(32);
  for(let i=0;i<4;i++){ let v=A[i]; for(let b=0;b<8;b++){ out[i*8+b]=Number(v&0xffn); v>>=8n; } }
  return out;
}
function hexToBytes(h){ h=h.replace(/^0x/,''); const o=new Uint8Array(h.length/2); for(let i=0;i<o.length;i++) o[i]=parseInt(h.substr(i*2,2),16); return o; }
function bytesToHex(b){ return '0x'+Array.from(b,x=>x.toString(16).padStart(2,'0')).join(''); }
function strBytes(s){ return new TextEncoder().encode(s); }
function concatBytes(...arrs){ let n=0; for(const a of arrs) n+=a.length; const o=new Uint8Array(n); let p=0; for(const a of arrs){ o.set(a,p); p+=a.length; } return o; }
function u16be(n){ return new Uint8Array([(n>>8)&255,n&255]); }
function u32be(n){ return new Uint8Array([(n>>>24)&255,(n>>>16)&255,(n>>>8)&255,n&255]); }
function u8(n){ return new Uint8Array([n&255]); }
// abi.encode of a uint: 32-byte big-endian
function word(n){ const o=new Uint8Array(32); let v=BigInt(n); for(let i=31;i>=0;i--){ o[i]=Number(v&0xffn); v>>=8n; } return o; }
// self-test
(function(){ const h=bytesToHex(keccak256(new Uint8Array(0))); if(h!=='0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470') throw new Error('keccak self-test failed '+h); })();

// ---------------------------------------------------------------------------
// Deterministic RNG: stream of bytes from keccak(seed), refilled by keccak(prev).
// Solidity: same construction (bytes32 pool, counter, rehash).
// ---------------------------------------------------------------------------
class Rng{
  constructor(seedBytes){ this.pool=keccak256(seedBytes); this.i=0; }
  byte(){ if(this.i===32){ this.pool=keccak256(this.pool); this.i=0; } return this.pool[this.i++]; }
  // uniform-ish int in [0,n)
  int(n){ return this.byte()%n; }
  // per-mille roll [0,1000) from two bytes (for the rarity weight tables)
  r1000(){ return (this.byte()*256+this.byte())%1000; }
  // jitter in [-2..2] with weight towards small values: bytes 0..255 → {-2,-1,-1,0,0,0,1,1,2}
  jit(){ const t=[-2,-1,-1,0,0,0,1,1,2]; return t[this.byte()%9]; }
  // pick from a 3-value stroke set
  sw(){ return [8,12,16][this.byte()%3]; }
}
function genesisSeed(genesisHash,tokenId){ return concatBytes(hexToBytes(genesisHash),u16be(tokenId)); }
// Provisional damage seed (open item O-3): keccak(genesisHash, tokenId, deaths)
function damageSeed(genesisHash,tokenId,deaths){ return concatBytes(hexToBytes(genesisHash),u16be(tokenId),u8(deaths),strBytes('DMG')); }
// Demo genesisHash for the workbench when the provider isn't wired: keccak("HOODRXCH_GENESIS_V1", tokenId)
function demoGenesisHash(tokenId){ return bytesToHex(keccak256(concatBytes(strBytes('HOODRXCH_GENESIS_V1'),word(tokenId)))); }
