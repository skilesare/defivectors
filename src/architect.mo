import T "./types";
import Vector "mo:vector";
import Map "mo:map/Map";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {
    public type ArchMem = {
        architects: Map.Map<Principal, Vector.Vector<T.DVectorId>>
    };
    public type ArchVectorsResult = {total:Nat; entries:[(T.DVectorId, T.DVectorShared)]};
    public class Architect({
        mem: ArchMem;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
        history_mem : Vector.Vector<T.History.Tx>;
    }) {

        public func add_vector(arch_id: Principal, vector_id: T.DVectorId) : () {
            switch (Map.get(mem.architects, Map.phash, arch_id)) {
                case (?ids) {
                    Vector.add(ids, vector_id);
                };
                case (null) {
                    let ids = Vector.new<T.DVectorId>();
                    Vector.add(ids, vector_id);
                    Map.set(mem.architects, Map.phash, arch_id, ids);
                }
            };
        };

        public func get_vectors(arch_id: Principal, start:Nat, length: Nat) : ArchVectorsResult {
            let ?ids = Map.get(mem.architects, Map.phash, arch_id) else return {total=0; entries=[]};
            let total = Vector.size(ids);
            let real_len = Nat.min(length, if (start > length) 0 else total - start);
            
            let entries = Array.tabulate<(T.DVectorId, T.DVectorShared)>(real_len, func (i) {
                let local_id = start + i;
                let id = Vector.get(ids, local_id);
                let ?v = Map.get(dvectors, Map.n32hash, id) else Debug.trap("Memory corruption VMF2H");
                let ?sv = T.DVector.toShared(history_mem, ?v) else Debug.trap("Memory corruption FJ3FD");
                (id, sv);
            });

            {total; entries};
        };
    }
}