export class EtaCorrectionModel {
  constructor(metadata) {
    this.metadata=metadata;
    const bytes=Uint8Array.from(atob(metadata.payload),c=>c.charCodeAt(0)),data=new DataView(bytes.buffer);
    if(data.byteLength<6||data.getUint32(0)!==0x45544131)throw new Error('INVALID_ETA_MODEL');
    this.trees=[];let offset=6;
    for(let t=0;t<data.getUint16(4,true);t++) {
      const count=data.getUint16(offset,true);offset+=2;const nodes=[];
      for(let n=0;n<count;n++,offset+=15)nodes.push({feature:data.getInt16(offset,true),value:data.getFloat64(offset+2,true),left:data.getInt16(offset+10,true),right:data.getInt16(offset+12,true)});
      this.trees.push(nodes);
    }
    if(offset!==data.byteLength)throw new Error('INVALID_ETA_MODEL_SIZE');
  }
  predict(vector) {
    if(vector.length!==this.metadata.feature_names.length||!vector.every(Number.isFinite))throw new Error('INVALID_ETA_FEATURES');
    let result=0;
    for(const nodes of this.trees){let node=nodes[0];while(node.feature>=0)node=nodes[vector[node.feature]<=node.value?node.left:node.right];result+=node.value;}
    if(!Number.isFinite(result))throw new Error('INVALID_ETA_PREDICTION');
    return result;
  }
  multiplier(vector) {
    return Math.max(this.metadata.minimum_multiplier,Math.min(this.metadata.maximum_multiplier,1+this.predict(vector)));
  }
}
