{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ExistentialQuantification  #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE OverloadedLists            #-}
------------------------------------------------------------------------------
module Swagger.Internal where
------------------------------------------------------------------------------
import           Control.Arrow
import           Control.Monad
import           Data.Aeson
import           Data.Hashable
import           Data.Monoid
import qualified Data.ByteString.Lazy.Char8 as BC
import           Data.Char
import qualified Data.HashMap.Strict as H
import           Data.Text (Text)
import qualified Data.Text as T
import           GHC.Generics
------------------------------------------------------------------------------
main :: IO ()
main = 
  BC.writeFile "foo.json" $ encode $ SwaggerAPI {
       _swaggerInfo    = SwaggerInfo (APITitle "foo") (APIVersion "2.0")
                            (APIDescription "Hooray") Nothing
    ,  _swaggerSchemes = Just [ Http ]
    ,  _swaggerPaths   = [(PathName "dogs", ps)]
    }
  where
    ps = SwaggerPath [(Get, xs)]
    xs = Path {
           _params    = [
              Param Query "foo" StringSwag Nothing "Foo query param" True Nothing
           ]
         , _summary   = "Get some dogs"
         , _responses = [(200, Response "success")]
         , _produces  = [ JSON, HTML ]
         , _consumes  = [ JSON, HTML ]
         }

newtype APIDescription =  APIDescription { _unApiDesc :: Text }
   deriving (Show, Eq, ToJSON)

newtype APITermsOfService = APITermsOfService { _unAPITermsOfService :: Text }
   deriving (Show, Eq, ToJSON)

data Response = Response {
     _description :: Text
  } deriving (Show, Eq)

data SwaggerAPI = SwaggerAPI {
     _swaggerInfo  :: SwaggerInfo
  ,  _swaggerPaths :: H.HashMap PathName SwaggerPath
  ,  _swaggerSchemes :: Maybe [Scheme]
  } deriving Show

data SwaggerInfo = SwaggerInfo {
    _swaggerInfoTitle      :: APITitle    
  , _swaggerVersion        :: APIVersion
  , _swaggerAPIDescription :: APIDescription
  , _license               :: Maybe APILicense
  } deriving (Show, Eq)

data APILicense = APILicense {
     _licenseName :: Text
  ,  _licenseUrl :: Maybe Text
  } deriving (Show, Eq)

data SwaggerPath = SwaggerPath {
     _paths :: H.HashMap Verb Path
  } deriving Show

instance Monoid SwaggerPath where
  mempty = SwaggerPath H.empty
  SwaggerPath a `mappend` SwaggerPath b =
    SwaggerPath ( a <> b )

instance ToJSON APILicense where
  toJSON APILicense{..} =
    object [ "name" .= _licenseName
           , "url"  .= _licenseUrl
           ]

data Verb = Post | Get | Put | Options | Head | Delete | Patch
  deriving (Show, Eq, Read, Generic)

instance Hashable Verb where hash = hash . show

data Path = Path {
     _summary   :: Text     
   , _params    :: [Param]
   , _responses :: H.HashMap Code Response
   , _produces  :: [ContentType]
   , _consumes  :: [ContentType]
  } deriving Show

newtype Code = Code Int
  deriving (Show, Eq, Ord, ToJSON, Hashable, Num)

data SwaggerType =
    StringSwag
  | IntSwag
  | BoolSwag
  | ArraySwag
  | NumberSwag
  | FileSwag
  deriving (Show, Eq)

instance ToJSON SwaggerType where
  toJSON StringSwag = String "string"
  toJSON IntSwag    = String "integer"
  toJSON NumberSwag = String "number"
  toJSON BoolSwag   = String "boolean"
  toJSON ArraySwag  = String "array"
  toJSON FileSwag   = String "file"

data ContentType = JSON | HTML | XML | FormEncoded | PlainText deriving (Show, Eq)
data In = PathUrl | Query | Header | FormData deriving Show
data Scheme = Http | Https | Ws | Wss deriving Show

instance ToJSON ContentType where
  toJSON JSON        = String "application/json"
  toJSON XML         = String "application/xml"
  toJSON FormEncoded = String "application/x-www-form-urlencoded"
  toJSON HTML        = String "text/html"
  toJSON PlainText   = String "text/plain; charset=utf-8"

instance ToJSON Scheme where
  toJSON Http = String "http" 
  toJSON Https = String "https" 
  toJSON Ws = String "ws" 
  toJSON Wss = String "wss" 

instance ToJSON In where
  toJSON PathUrl = "path"
  toJSON Query = "query"
  toJSON Header = "header"
  toJSON FormData = "formData"

data Param = Param {
    _in  :: In
  , _name :: Text
  , _type :: SwaggerType
  , _items :: Maybe ItemObject --if type ArraySwag
  , _paramDescription :: Text
  , _required :: Bool
  , _default :: Maybe Value
  } deriving Show

data ItemObject = ItemObject {
     _itemsType :: SwaggerType
  } deriving Show

newtype APIVersion = APIVersion Text deriving (Show, Eq, ToJSON)
newtype APITitle = APITitle Text deriving (Show, Eq, ToJSON)
newtype PathName = PathName { unPathName :: Text } deriving (Show, Eq, Hashable)

instance ToJSON PathName where
  toJSON (PathName x) = String (T.toLower x)

data SwagModel = SwagModel {
    
  }

class (Eq a, Show a) => ToSwagModel a where
  toSwagModel :: a -> SwagModel

instance ToJSON SwaggerAPI where
  toJSON SwaggerAPI{..} =
    object [
        "swagger" .= ("2.0" :: Text)
      , "schemes" .= _swaggerSchemes
      , "info"    .= _swaggerInfo
      , "paths"   .= Object (H.fromList $ map f $ H.toList _swaggerPaths)
      ]
    where
      f (PathName pathName, sp) = (T.toLower pathName, toJSON sp)

instance ToJSON SwaggerPath where
  toJSON (SwaggerPath paths) = 
     Object . H.fromList . map f . H.toList $ paths
    where
      f (verb, sp) = (T.toLower $ toTxt verb, toJSON sp)

instance ToJSON Path where
  toJSON Path {..} =
    object [  "parameters" .= _params
            , "responses"  .= (Object . H.fromList . map f . H.toList $ _responses)
            , "produces"   .= _produces 
            , "summary"    .= _summary  
            ] 
    where f (Code x, resp) = (toTxt x, toJSON resp)
  
instance ToJSON Response where
  toJSON Response {..} = object [ "description" .= _description ]

instance ToJSON Param where
  toJSON Param{..} = 
    object [
        "in"   .= _in
      , "name" .= _name
      , "type" .= _type
      , "description" .= _paramDescription
      , "required" .= _required
      ]

instance ToJSON SwaggerInfo where
  toJSON SwaggerInfo{..} =
    object $ [
        "title"   .= _swaggerInfoTitle
      , "version" .= _swaggerVersion
      , "description" .= _swaggerAPIDescription
      ] ++ (maybe [] (pure .  ("license" .=)) _license)

toTxt :: Show a => a -> Text
toTxt = T.pack . show
