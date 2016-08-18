module Main

import public Lightyear
import public Lightyear.Char
import public Lightyear.Strings

import Combi
import Data.String

data Val = A String -- atom
         | L (List Val) -- list
         | D (List Val) Val -- Dotted List
         | N Integer -- num
         | S String -- string
         | B Bool -- bool

mutual
  unwordsList : List Val -> String
  unwordsList = unwords . map showVal

  showVal : Val -> String
  showVal (A x) = x
  showVal (L xs) = "(" ++ unwordsList xs ++ ")"
  showVal (D xs x) = "(" ++ unwordsList xs ++ " . " ++ showVal x ++ ")"
  showVal (N x) = show x
  showVal (S x) = "\"" ++ x ++ "\""
  showVal (B True) = "#t"
  showVal (B False) = "#f"

Show Val where
  show = showVal

symbol : Parser Char
symbol = oneOf "!#$%&|*+-/:<=>?@^_~"

spaces : Parser ()
spaces = skipMany1 space

parseString : Parser Val
parseString = do
                char '"'
                x <- many $ noneOf "\""
                char '"'
                return $ S $ pack x

parseAtom : Parser Val
parseAtom = do
              fst <- letter <|> symbol
              rest <- many (alphaNum <|> symbol)
              let atom = pack $ fst :: rest
              return $ case atom of
                            "#t" => B True
                            "#f" => B False
                            otherwise => A atom

positiveInt : (Num n, Monad m, Stream Char s) => ParserT s m n
positiveInt = do
                ds <- some digit
                let theInt = getInteger ds
                pure $ fromInteger theInt
              where
                getInteger : List (Fin 10) -> Integer
                getInteger = foldl (\a => \b => 10 * a + cast b) 0

parseNumber : Parser Val
parseNumber = return $ N !positiveInt

mutual
  parseQuoted : Parser Val
  parseQuoted = do
                  char '\''
                  return $ L [(A "quote"), !parseExpr]

  parseList : Parser Val
  parseList = return $ L !(sepBy parseExpr Main.spaces)

  parseDottedList : Parser Val
  parseDottedList = do
                      head <- endBy parseExpr Main.spaces
                      tail <- do
                                char '.'
                                Main.spaces
                                parseExpr
                      return $ D head tail

  parseExpr : Parser Val
  parseExpr = parseAtom
           <|> parseString
           <|> parseNumber
           <|> parseQuoted
           <|> do char '('
                  x <- parseList
                  char ')'
                  return x
           <|> do char '('
                  x <- parseDottedList
                  char ')'
                  return x

readExpr : String -> Val
readExpr str = case parse parseExpr str of
                   Left err => S $ "No match: " ++ show err
                   Right v  => v

-- reads : String -> Maybe Integer
-- reads x = parseInteger (takeWhile isDigit (unpack x))
-- foldr : (func : elem -> acc -> acc) -> (init : acc) -> (input : t elem) -> acc
reads : String -> Maybe Integer
reads s = parseInteger $ pack $ snd (foldl func (True, List.Nil) (unpack s))
          where
            func : (Bool, List Char) -> Char -> (Bool, List Char)
            func y x = if fst y
                       then
                          case parseInteger (pack ((snd y) ++ [x])) of
                            Just _  => (True, ((snd y) ++ [x]))
                            Nothing => (False, (snd y))
                        else
                          (False, (snd y))

unpackNumString : (n : String) -> Integer
unpackNumString n = ?unpackNumString_rhs

unpackNum : Val -> Integer
unpackNum (A x)    = ?unpackNum_rhs_1
unpackNum (L [n])  = unpackNum n
unpackNum (D xs x) = ?unpackNum_rhs_3
unpackNum (N n)    = n
unpackNum (S n)    = unpackNumString n
unpackNum (B x)    = ?unpackNum_rhs_6

numericBinop : (Integer -> Integer -> Integer) -> List Val -> Val
numericBinop op params = N $ foldl1 op $ map unpackNum params

primitives : List (String, List Val -> Val)
primitives = [("+", numericBinop (+)),
              ("-", numericBinop (-)),
              ("*", numericBinop (*)),
              ("/", numericBinop div),
              ("mod", numericBinop mod),
              ("quotient", numericBinop divBigInt),
              ("remainder", numericBinop modBigInt)]

apply' : (func : String) -> (args : List Val) -> Val
apply' func args = ?what (lookup func primitives)

eval : Val -> Val
eval (A x) = ?eval_rhs_1 -- todo
eval (L [A "quote", val]) = val
eval (L (A func :: args)) = apply' func $ map eval args
eval (D xs x) = ?eval_rhs_3 -- todo
eval val@(N x) = val
eval val@(S x) = val
eval val@(B x) = val

hex : Parser Int
hex = do
  c <- map (ord . toUpper) $ satisfy isHexDigit
  pure $ if c >= ord '0' && c <= ord '9' then c - ord '0'
                                         else 10 + c - ord 'A'

hexQuad : Parser Int
hexQuad = do
  a <- hex
  b <- hex
  c <- hex
  d <- hex
  pure $ a * 4096 + b * 256 + c * 16 + d

main : IO ()
main = do
       (_ :: expr :: _) <- getArgs
       putStrLn $ show $ readExpr expr