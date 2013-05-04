module Language.Haskell.Exts.Annotated.CPP
  ( parseFileWithCommentsAndCPP
  , parseFileContentsWithCommentsAndCPP
  , defaultCpphsOptions
  , CpphsOptions(..)
  , BoolOptions(..)
  ) where

import qualified Language.Preprocessor.Cpphs as Orig
import Language.Preprocessor.Cpphs hiding (defaultCpphsOptions)
import Language.Preprocessor.Unlit
import Language.Haskell.Exts (ParseMode(..))
import Language.Haskell.Exts.Annotated
import Control.Applicative
import Data.List

parseFileWithCommentsAndCPP ::  CpphsOptions -> ParseMode -> FilePath
                      -> IO (ParseResult (Module SrcSpanInfo, [Comment]))
parseFileWithCommentsAndCPP cppopts parseMode0 file = do
    content <- readFile file
    parseFileContentsWithCommentsAndCPP cppopts parseMode content
  where
    parseMode = parseMode0 { parseFilename = file }

parseFileContentsWithCommentsAndCPP
    :: CpphsOptions -> ParseMode -> String
    -> IO (ParseResult (Module SrcSpanInfo, [Comment]))
parseFileContentsWithCommentsAndCPP cppopts p rawStr = do
    let filename = parseFilename p
        md = delit filename rawStr
        exts = extensions p
        oldLang = baseLanguage p
        (bLang, extraExts) =
            case (ignoreLanguagePragmas p, readExtensions md) of
              (False, Just (mLang, es)) ->
                   (case mLang of {Nothing -> oldLang;Just newLang -> newLang}, es)
              _ -> (oldLang, [])
        p' = p { extensions = exts ++ extraExts
               , ignoreLanguagePragmas = False
               , baseLanguage = bLang
               }
    processedSrc <- cpp cppopts p' md
    return $ parseFileContentsWithComments p' processedSrc

cpp cppopts p str
  | CPP `elem` impliesExts (toExtensionList (baseLanguage p) (extensions p))
  = runCpphs cppopts (parseFilename p) str
  | otherwise = return str

delit :: String -> String -> String
delit fn = if ".lhs" `isSuffixOf` fn then unlit fn else id

defaultCpphsOptions =
  Orig.defaultCpphsOptions
  { boolopts = (boolopts Orig.defaultCpphsOptions)
      { locations = True
      , stripC89 = True
      , stripEol = False
      , hashline = False
      }
  }
