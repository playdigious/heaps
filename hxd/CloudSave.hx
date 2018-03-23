package hxd;

class CloudSave
{
    #if !standalone
    @:hlNative("ach","send_save") static function _sendSave( saveName:hl.Bytes, save : hl.Bytes, size:Int ) : Bool { return false; }
    @:hlNative("ach","receive_save") static function _receiveSave( saveName:hl.Bytes ) : Bool { return false; }
    @:hlNative("ach","has_save") static function _hasSave( saveName:hl.Bytes ) : Bool { return false; }
    #end

    public static function sendSave( saveName:String, save:String ) : Bool 
    {
        #if !standalone
       @:privateAccess return _sendSave( saveName.bytes, save.bytes, save.length );
       #end
       return false;
    }

    public static function receiveSave(saveName:String) : Bool 
    {
        #if !standalone
        @:privateAccess return _receiveSave(saveName.bytes);
        #end
        return false;
    }

    public static function hasSave(saveName:String) : Bool 
    {
        #if !standalone
        @:privateAccess return _hasSave(saveName.bytes);
        #end
        return false;
    }
   
}
