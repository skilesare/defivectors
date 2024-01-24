import Ledger "./services/icrc_ledger";
import I "mo:itertools/Iter";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Vector "mo:vector";
import Nat "mo:base/Nat";

module {

    public type DVectorId = Nat32;
    public type Timestamp = Nat32;

    public type TokenId = Nat16;

    public type SwapRequest = {
        id : DVectorId;
        amount : Nat;
    };

    public type SwapResult = {
        recievedSource: Nat;
        sentDestination: Nat;
        returnedDestination: Nat;
    };

    public type SourceEndpointInput = {
        ledger : Principal;
    };

    public type DestinationEndpointInput = {
        address : ?Ledger.Account; // specify if external
        ledger : Principal;
    };

    public type Endpoint = {
        address : Ledger.Account;
        ledger_decimals: Nat;
        ledger_fee: Nat; 
        ledger_symbol : Text;
        ledger : Principal;
    };

    public type AlgoRate = {
        max : Float;
        discount: Float;
    };

    public type DVectorRequest = {
        source : SourceEndpointInput;

        destination : DestinationEndpointInput;

        // Rate - serves to calculate the amount taker has to give
        algorate: AlgoRate;
    };



    public type DVector = {
        owner : Principal;
        created : Timestamp;
        source : Endpoint;
        var source_balance : Nat;
        var amount_available : Nat;
        destination : Endpoint;
        var destination_balance : Nat;
        algorate: AlgoRate;
        var rate : Float;
        var active : Bool;
        var unconfirmed_transactions : [UnconfirmedTransaction];
        history : Vector.Vector<History.TxId>;
    };

    public func sumAmountInTransfers(v: DVector) : Nat {
        var sum:Nat = 0;
        for (v in v.unconfirmed_transactions.vals()) {
            sum := sum + v.amount;
        };
        sum;
    };

    public type UnconfirmedTransaction = {
        id : Nat64;
        amount : Nat;
        timestamp : Timestamp;
        to :Ledger.Account;
        from : Ledger.Account;
        fee : Nat;
        from_id : DVectorId;
        to_id : DVectorId;
        memo : Blob;
        var tries : Nat;
    };

    public type UnconfirmedTransactionShared = {
        amount : Nat;
        timestamp : Timestamp;
        to :Ledger.Account;
        from : Ledger.Account;
        fee : Nat;
        from_id : DVectorId;
        to_id : DVectorId;
        memo : Blob;
        tries : Nat;
    };

    public type DVectorShared = {
        owner : Principal;
        created : Timestamp;
        source : Endpoint;
        source_balance : Nat;
        amount_available : Nat;
        destination : Endpoint;
        destination_balance : Nat;
        algorate: AlgoRate;
        rate: Float;
        active : Bool;
        unconfirmed_transactions : [UnconfirmedTransactionShared];
    };



    public module DVector {
        public func toShared(history: Vector.Vector<History.Tx>, tr: ?DVector) : ?DVectorShared {
            let ?t = tr else return null;
            ?{
                t with
                source_balance = t.source_balance;
                rate = t.rate;
                active = t.active;
                unconfirmed_transactions = Array.map<UnconfirmedTransaction, UnconfirmedTransactionShared>(t.unconfirmed_transactions, UnconfirmedTransaction.toShared);
                amount_available = t.amount_available;
                destination_balance = t.destination_balance;
            }
        }
    };

    public module History {
        public type TxId = Nat;
        public type Tx = {
            kind : TxKind;
            timestamp : Timestamp;
        };
        public type TxKind = {
            #source_in : {
                vid : DVectorId;
                amount : Nat;
                fee : Nat;
            };
            #destination_in : {
                vid : DVectorId;
                amount : Nat;
                fee : Nat;
                vtx_id : ?Nat64;
            };
            #source_out : {
                vid : DVectorId;
                amount : Nat;
                fee : Nat;
            };
            #destination_out : {
                vid : DVectorId;
                amount : Nat;
                fee : Nat;
            };
            #tx_initiated : {
                vtx_id : Nat64;
                from : DVectorId;
                to : DVectorId;
                amount : Nat;
                fee : Nat;
                rate : Float;
            };
            #tx_sent : {
                vtx_id : Nat64;
                retry : Nat;
                error : Bool;
            };
        };



        public func getVectorHistory(history: Vector.Vector<History.Tx>, vec_history: Vector.Vector<TxId>, start:Nat, len:Nat) : [(History.TxId, History.Tx)] {
            
            Array.tabulate<(History.TxId, History.Tx)>(len, func (i) {
                let id = Vector.get(vec_history, start + i);
                let tx = Vector.get(history, id);
                (id, tx);
            });
        };

        public type HistoryResponse = {
            total: Nat;
            entries: [(TxId, Tx)];
        }
    };

    public module UnconfirmedTransaction {
        public func toShared(t: UnconfirmedTransaction) : UnconfirmedTransactionShared {
            {
                t with
                tries = t.tries;
            }
        }
    };

    public func now() : Timestamp {
        Nat32.fromNat(Int.abs(Time.now() / 1000000000));
    };

    public func getDVectorSubaccount(vid : DVectorId, who : { #source; #destination }) : Blob {
        let whobit : Nat8 = switch (who) {
            case (#source) 1;
            case (#destination) 2;
        };
        Blob.fromArray(Iter.toArray(I.pad(I.flattenArray<Nat8>([[whobit], ENat32(vid)]), 32, 0 : Nat8)));
    };

    public func getPrincipalSubaccount(p : Principal) : Blob {
        let a = Array.init<Nat8>(32, 0);
        let pa = Principal.toBlob(p);
        a[0] := Nat8.fromNat(pa.size());

        var pos = 1;
        for (x in pa.vals()) {
                a[pos] := x;
                pos := pos + 1;
            };

        Blob.fromArray(Array.freeze(a));
    };

    public func ENat64(value : Nat64) : [Nat8] {
        return [
            Nat8.fromNat(Nat64.toNat(value >> 56)),
            Nat8.fromNat(Nat64.toNat((value >> 48) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 40) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 32) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 24) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 16) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 8) & 255)),
            Nat8.fromNat(Nat64.toNat(value & 255)),
        ];
    };

    public func DNat64(array : [Nat8]) : ?Nat64 {
        if (array.size() != 8) return null;
        return ?(Nat64.fromNat(Nat8.toNat(array[0])) << 56 | Nat64.fromNat(Nat8.toNat(array[1])) << 48 | Nat64.fromNat(Nat8.toNat(array[2])) << 40 | Nat64.fromNat(Nat8.toNat(array[3])) << 32 | Nat64.fromNat(Nat8.toNat(array[4])) << 24 | Nat64.fromNat(Nat8.toNat(array[5])) << 16 | Nat64.fromNat(Nat8.toNat(array[6])) << 8 | Nat64.fromNat(Nat8.toNat(array[7])));
    };

    private func ENat32(value : Nat32) : [Nat8] {
        return [
            Nat8.fromNat(Nat32.toNat(value >> 24)),
            Nat8.fromNat(Nat32.toNat((value >> 16) & 255)),
            Nat8.fromNat(Nat32.toNat((value >> 8) & 255)),
            Nat8.fromNat(Nat32.toNat(value & 255)),
        ];
    };

    public func getFloatRate(amount1: Nat, decimals1: Nat, amount2:Nat, decimals2:Nat) : Float {
        let r0 = floatAmount(amount1, decimals1); 
        let r1 = floatAmount(amount2, decimals2); 
        
        (r1 / r0);
    };

    public func floatAmount(amount: Nat, decimals:Nat) : Float {
        Float.fromInt(amount)/ (10 ** Float.fromInt(decimals)); 
    };

    public func natAmount(amount: Float, decimals:Nat) : Nat {
        Int.abs(Float.toInt(amount * (10 ** Float.fromInt(decimals)))); 
    };

    public type LedgerMeta = {
        symbol : Text;
        decimals : Nat;
        fee : Nat;
    };

    public func ledgerMeta( ledger_id : Principal ) : async LedgerMeta {
        let ledger = actor (Principal.toText(ledger_id)) : Ledger.Self;
        let meta = await ledger.icrc1_metadata();

        let ?#Text(symbol) = findLedgerMetaVal("icrc1:symbol", meta) else Debug.trap("Can't find ledger symbol");
        let ?#Nat(fee) = findLedgerMetaVal("icrc1:fee", meta) else Debug.trap("Can't find ledger fee");
        let ?#Nat(decimals) = findLedgerMetaVal("icrc1:decimals", meta) else Debug.trap("Can't find ledger decimals");

        {symbol; decimals; fee};
    };


    private func findLedgerMetaVal(key : Text, values : [(Text, Ledger.MetadataValue)]) : ?Ledger.MetadataValue {
        let ?f = Array.find<(Text, Ledger.MetadataValue)>(values, func((k : Text, d : Ledger.MetadataValue)) = k == key) else return null;
        ?f.1;
    };
};
