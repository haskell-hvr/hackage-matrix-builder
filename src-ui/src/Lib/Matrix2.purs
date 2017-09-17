module Lib.MatrixApi2 where

import Prelude (Unit, pure, bind, otherwise, (<>), ($), (<<<), (<$>), show, (/=), (==))
import Network.HTTP.Affjax as Affjax
import Network.HTTP.Affjax.Request (class Requestable)
import Control.Monad.Aff.Class (class MonadAff, liftAff)
import Data.Traversable as TRV
import Data.Maybe (Maybe(..))
import Data.Argonaut.Core as Arg
import Data.Argonaut.Decode as Arg
import Data.Either (Either(..))
import Data.HTTP.Method (Method(..))
import Network.RemoteData as RD
import Control.Monad.Reader (class MonadReader, ReaderT)
import Control.Monad.Eff.Ref (Ref)
import Control.Monad.Eff.Exception as E
import Control.Monad.Eff
import Control.Monad.Aff (Aff)
import Data.StrMap as SM
import Data.Int as Int
import Data.Array as Arr
import Data.Tuple as Tuple
import Halogen.Aff (HalogenEffects)
import DOM
import DOM.HTML.Types as DOM

import Lib.MiscFFI as Misc
import Lib.Types as T
import Lib.MatrixApi as Api

type Environment2 =
  {
    packages :: Ref (RD.RemoteData E.Error (Array T.PackageName))
  }

type MatrixApi2 eff =
  ReaderT Environment2
          (Aff
            (HalogenEffects ( ajax :: Affjax.AJAX
                            , dom :: DOM
                            , history :: DOM.HISTORY| eff)))

getTimestamp :: forall e m a b. MonadAff (ajax :: Affjax.AJAX | e) m
             => T.PackageName
             -> m (RD.RemoteData String Arg.Json)
getTimestamp pkgName = do
  res <- liftAff (Affjax.affjax Affjax.defaultRequest {
                                   url = "/api/v2/packages/" <> pkgName <> "/reports"
                                 , method = Left GET
                                 })
  let
    decodedApi = Arg.decodeJson (res.response :: Arg.Json)
  pure (RD.fromEither decodedApi)

getLatestReportByPackageTimestamp :: forall e m. MonadAff (ajax :: Affjax.AJAX | e) m
                                  => T.PackageName
                                  -> T.PackageTS
                                  -> m (RD.RemoteData E.Error Arg.Json)
getLatestReportByPackageTimestamp pkgName pkgTs = do
  res <- liftAff (Affjax.affjax Affjax.defaultRequest {
                                   url = "/api/v1.0.0/package/name/" <> pkgName <> "/report/idxstate/"<> pkgTs
                                 , method = Left GET
                                 })
  let
    decodedApi = Arg.decodeJson (res.response :: Arg.Json)
  case decodedApi of
    (Right a) -> pure (RD.Success a)
    (Left e)  -> pure (RD.Failure (E.error e))

-- TODO: This function signature MUST be changed after API v2 fully implemented
getPackages :: forall e m a. MonadReader (Api.Environment e) m
            => MonadAff
                 (HalogenEffects (api :: Api.API
                                 , ajax :: Affjax.AJAX
                                 , dom :: DOM, history :: DOM.HISTORY| e)) m
            => m (RD.RemoteData E.Error Arg.Json)
getPackages = do
  res <- liftAff (Affjax.affjax Affjax.defaultRequest
                        {
                          url = "/api/v2/packages"
                          , method = Left GET
                        })
  let
    decodedApi = Arg.decodeJson (res.response :: Arg.Json)
  case decodedApi of
    (Right a) -> pure (RD.Success a)
    (Left e)  -> pure (RD.Failure (E.error e))

getTagsByPackageName :: forall e m a. MonadAff (ajax :: Affjax.AJAX | e) m
                     => T.PackageName
                     -> m (RD.RemoteData E.Error Arg.Json)
getTagsByPackageName pkgName = do
  res <- liftAff (Affjax.affjax Affjax.defaultRequest
                        {
                          url = "/api/v2/packages/" <> pkgName <> "/tags"
                          , method = Left GET
                        })
  let
    decodedApi = Arg.decodeJson (res.response :: Arg.Json)
  case decodedApi of
    (Right a) -> pure (RD.Success a)
    (Left e)  -> pure (RD.Failure (E.error e))

getTagsInfo :: forall e m a b. MonadAff (ajax :: Affjax.AJAX | e) m
             => T.PackageName
             -> m (RD.RemoteData E.Error Arg.Json)
getTagsInfo pkgName = do
  res <- liftAff (Affjax.affjax Affjax.defaultRequest {
                                   url = "/api/v2/tags/?pkgnames"
                                 , method = Left GET
                                 })
  let
    decodedApi = Arg.decodeJson (res.response :: Arg.Json)
  case decodedApi of
    (Right a) -> pure (RD.Success a)
    (Left e)  -> pure (RD.Failure (E.error e))

putTagsByPackage :: forall e m. MonadAff (ajax :: Affjax.AJAX | e) m
                 => T.TagName
                 -> T.PackageName
                 -> m (Affjax.AffjaxResponse Unit)
putTagsByPackage tagName pkgName = do
  let
    url = "/api/v2/tags/" <> tagName <> "/" <> pkgName
    dt = Arg.jsonEmptyString
  liftAff ( Affjax.put_ url dt )

deleteTagsByPackage :: forall e m. MonadAff (ajax :: Affjax.AJAX | e) m
                 => T.TagName
                 -> T.PackageName
                 -> m (Affjax.AffjaxResponse Unit)
deleteTagsByPackage tagName pkgName = do
  let
    url = "/api/v2/tags/" <> tagName <> "/" <> pkgName
  liftAff ( Affjax.delete_ url)

parseJsonToArrayS :: forall e m. MonadAff (ajax :: Affjax.AJAX | e) m
                   => RD.RemoteData E.Error Arg.Json
                   -> m (RD.RemoteData E.Error (Array String))
parseJsonToArrayS (RD.Success a) =
  case Arg.toArray a of
    (Just a') ->
      case TRV.traverse Arg.toString a' of
        (Just jStr) -> pure (RD.Success jStr)
        Nothing     -> pure (RD.Failure (E.error "Json is not String"))
    Nothing   -> pure (RD.Failure (E.error "Json is not Array"))

parseJsonToArrayS (RD.Failure e) = pure $ RD.Failure e
parseJsonToArrayS RD.Loading = pure RD.Loading
parseJsonToArrayS RD.NotAsked = pure RD.NotAsked

parseShallowReport :: forall e m a. MonadAff (ajax :: Affjax.AJAX | e) m
                   => RD.RemoteData E.Error Arg.Json
                   -> m (RD.RemoteData E.Error T.ShallowReport)
parseShallowReport (RD.Success a) =
  case Arg.toObject a of
    Just a' ->
      let
        packageName' =
          case SM.lookup "packageName" a' of
            Just pkgName ->
              case Arg.toString pkgName of
                Just pkgName' -> pkgName'
                Nothing -> "package is not String"
            Nothing -> "package name does not exist"
        modified' =
          case SM.lookup "modified" a' of
            Just mod ->
              case Arg.toString mod of
                Just mod' -> mod'
                Nothing -> "modified is not string"
            Nothing -> "modified does not exist"
        results' =
          case SM.lookup "results" a' of
            Just res ->
              case Arg.toArray res of
                Just res' -> parseShallowGhcResult (TRV.traverse Arg.toObject res')
                Nothing -> []
            Nothing -> []
      in pure $ RD.Success
                  { packageName : packageName'
                  , modified : modified'
                  , results : results'
                  }
    Nothing -> pure $ RD.Failure (E.error "This is not an Object")
parseShallowReport (RD.Failure e) = pure $ RD.Failure e
parseShallowReport RD.Loading = pure RD.Loading
parseShallowReport RD.NotAsked = pure RD.NotAsked

shallowReportDefault :: T.ShallowReport
shallowReportDefault =
  { packageName: ""
  , modified: ""
  , results: []
  }

parseShallowGhcResult :: Maybe (Array Arg.JObject) -> Array T.ShallowGhcResult
parseShallowGhcResult (Just a) = singleShallowGhcResult <$> a
parseShallowGhcResult Nothing = []

singleShallowGhcResult :: Arg.JObject -> T.ShallowGhcResult
singleShallowGhcResult jObj =
  let
    ghcVer' =
      case SM.lookup "ghcVersion" jObj of
        Just ver ->
          case Arg.toString ver of
            Just ver' -> ver'
            Nothing -> "version is not String"
        Nothing -> "version does not exist"
    ghcFullVer' =
      case SM.lookup "ghcFullVersion" jObj of
        Just fullVer ->
          case Arg.toString fullVer of
            Just fullVer' -> fullVer'
            Nothing -> "full version is not String"
        Nothing -> "full version does not exist"
    ghcResult' =
      case SM.lookup "ghcResult" jObj of
        Just result ->
          case Arg.toArray result of
            Just result' -> parseShallowVersionResult (TRV.traverse Arg.toObject result')
            Nothing -> []
        Nothing -> []
  in
   { ghcVersion : ghcVer'
   , ghcFullVersion : ghcFullVer'
   , ghcResult : ghcResult'
   }

shallowGhcResultDefault :: T.ShallowGhcResult
shallowGhcResultDefault =
  { ghcVersion     : ""
  , ghcFullVersion : ""
  , ghcResult      : []
  }

parseShallowVersionResult :: Maybe (Array Arg.JObject) -> Array T.ShallowVersionResult
parseShallowVersionResult (Just a) = singleShallowVersionResult <$> a
parseShallowVersionResult Nothing = []

singleShallowVersionResult :: Arg.JObject -> T.ShallowVersionResult
singleShallowVersionResult jObj =
  let
    pkgVer' =
      case SM.lookup "packageVersion" jObj of
        Just ver ->
          case Arg.toString ver of
            Just ver' -> ver'
            Nothing -> "version is not String"
        Nothing -> "version does not exist"
    pkgRev' =
      case SM.lookup "packageRevision" jObj of
        Just rev ->
          case Arg.toNumber rev of
            Just rev' -> Int.round rev'
            Nothing -> 0
        Nothing -> 0
    result' =
      case SM.lookup "result" jObj of
        Just result ->
          case Arg.toObject result of
            Just result' -> parseShallowResult result'
            Nothing -> T.Unknown
        Nothing -> T.Unknown
  in
   { packageVersion : pkgVer'
   , packageRevision : pkgRev'
   , result : result'
   }

parseShallowResult :: Arg.JObject -> T.ShallowResult
parseShallowResult jObj =
  case Arr.head (SM.keys jObj) of
    Just a -> toShallowResult a
    Nothing -> T.Unknown

toShallowResult :: String -> T.ShallowResult
toShallowResult  str
  | str == "ok" = T.ShallowOk
  | str == "nop" = T.ShallowNop
  | str == "noIp" = T.ShallowNoIp
  | str == "noIpBjLimit" = T.ShallowNoIpBjLimit 0
  | str == "noIpFail" = T.ShallowNoIpFail
  | str == "fail" = T.ShallowFail
  | str == "failDeps" = T.ShallowFailDeps 0
  | otherwise = T.Unknown



shallowVersionResultDefault :: T.ShallowVersionResult
shallowVersionResultDefault =
 { packageVersion  : ""
 , packageRevision : 0
 , result          : T.Unknown
 }

latestIndex :: forall e m. MonadAff (ajax :: Affjax.AJAX | e) m
            => T.PackageName
            -> m (Tuple.Tuple T.PackageName String)
latestIndex pkgName = do
  idx <- getTimestamp pkgName
  case idx of
    RD.Success idx -> getIdx ((show <<< Int.round) <$> (Misc.fromIndexToNumber (Arg.toArray idx))) pkgName
    _              -> pure $ Tuple.Tuple "" ""
  where
    getIdx idx' pkg'=
      case Arr.last idx' of
        Just a  -> pure $ Tuple.Tuple pkg' a
        Nothing -> pure $ Tuple.Tuple "" ""
