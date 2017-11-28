package hxd;

class CloudSave
{
    @:hlNative("ach","send_save") static function _sendSave( saveName:hl.Bytes, save : hl.Bytes, size:Int ) : Bool { return false; }
    @:hlNative("ach","receive_save") static function _receiveSave( saveName:hl.Bytes ) : Bool { return false; }
    @:hlNative("ach","has_save") static function _hasSave( saveName:hl.Bytes ) : Bool { return false; }
    
    public static function sendSave( saveName:String, save:String ) : Bool 
    {
       @:privateAccess return _sendSave( saveName.bytes, save.bytes, save.length );
    }

    public static function receiveSave(saveName:String) : Bool 
    {
        @:privateAccess return _receiveSave(saveName.bytes);
    }

    public static function hasSave(saveName:String) : Bool 
    {
        @:privateAccess return _hasSave(saveName.bytes);
    }
}
